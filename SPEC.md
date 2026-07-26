# Hive Browser — Definitive UI/UX Specification

> **Purpose:** This document is the single source of truth for every pixel, animation, interaction, and design decision in Hive Browser. It is research-backed, codebase-aware, and anti-slop by design.
>
> **Scope:** Every visual element, every interaction pattern, every animation curve, every color, every spacing value, every typography style, every edge case, every empty state, every error state, every accessibility accommodation.
>
> **Principle:** If it's not in this document, it doesn't ship.

---

## Table of Contents

1. [Design Philosophy](#1-design-philosophy)
2. [Color System](#2-color-system)
3. [Typography System](#3-typography-system)
4. [Spacing & Grid System](#4-spacing--grid-system)
5. [Motion & Animation System](#5-motion--animation-system)
6. [Liquid Glass & Materials](#6-liquid-glass--materials)
7. [Window Chrome Architecture](#7-window-chrome-architecture)
8. [Tab Bar System](#8-tab-bar-system)
9. [Sidebar System](#9-sidebar-system)
10. [Omnibar & Command Palette](#10-omnibar--command-palette)
11. [Content Area](#11-content-area)
12. [Split View System](#12-split-view-system)
13. [Download Manager](#13-download-manager)
14. [Privacy & Security UI](#14-privacy--security-ui)
15. [Context Menus, Popovers & Tooltips](#15-context-menus-popovers--tooltips)
16. [Drag & Drop System](#16-drag--drop-system)
17. [Notification & Toast System](#17-notification--toast-system)
18. [Error & Empty States](#18-error--empty-states)
19. [Onboarding](#19-onboarding)
20. [Settings](#20-settings)
21. [Keyboard Shortcuts](#21-keyboard-shortcuts)
22. [Accessibility](#22-accessibility)
23. [Theme System](#23-theme-system)
24. [Start Page](#24-start-page)
25. [Reader Mode](#25-reader-mode)
26. [Swarm Workspace](#26-swarm-workspace)
27. [Icons & Imagery](#27-icons--imagery)
28. [Performance Budget](#28-performance-budget)
29. [Anti-Slop Rules](#29-anti-slop-rules)
30. [Layout Modes — Detailed Spec](#30-layout-modes--detailed-spec)

---

## 1. Design Philosophy

### 1.1 Core Thesis

Hive is not an "AI browser." It is a **browser-native workspace** where browsing becomes persistent knowledge and organized workflow. The UI must communicate this through density, speed, and confidence — not through AI gimmicks, gradient text, or glassmorphism overuse.

### 1.2 Design Principles (in priority order)

1. **Functional over decorative.** Every visual element exists to serve a purpose. If removing it doesn't break comprehension, remove it.
2. **Dense but not cluttered.** Power users want information density. The UI should feel like a cockpit instrument panel, not a marketing landing page.
3. **Fast everywhere.** No animation should exceed 450ms. No interaction should feel delayed. The UI should feel like it's reading the user's mind.
4. **Dark-first.** Dark mode is the primary canvas. Light mode is a conscious adaptation, not an afterthought.
5. **Apple-native, not Apple-clone.** Use system frameworks (SwiftUI, AppKit) and respect HIG conventions, but develop a distinct visual identity through the warm amber accent, the near-black palette, and the tight typography.
6. **Local-first by default.** The UI should never suggest that data leaves the device unless the user explicitly configures it.

### 1.3 Anti-Slop Manifesto

These are **hard rules**, not guidelines:

| Slop Pattern | Rule |
|---|---|
| Gradient text | **Never.** Text is always a solid color. |
| Numbered section markers | **Never.** Don't label sections "01", "02", "03". |
| Symmetrical card grids | **Avoid.** Use asymmetric layouts with hierarchy. |
| Bouncy spring on everything | **Never.** Springs are functional — use critically damped springs for most UI. |
| Fade-in on scroll | **Never for chrome.** Content may fade, but chrome should be instant. |
| Glassmorphism overuse | **Never.** Glass is for navigation layers only, never content. |
| Centered everything | **Avoid.** Left-align content. Center only for hero/start page. |
| Generic blue/purple accents | **Never.** Hive's accent is warm amber (#FFC824 dark / #D99E00 light). |
| "Clean" meaning "empty" | **Never.** Density is a feature, not a bug. |
| AI sparkle icons | **Never.** AI is embedded, not branded. |

---

## 2. Color System

### 2.1 Philosophy

The color system is **warm neutral with a single accent**. No rainbow. No gradient. No "AI blue." The palette communicates calm authority through near-black backgrounds, warm gray text, and a gold accent that signals interactivity.

### 2.2 Semantic Tokens — Dark Mode (Primary)

| Token | Hex | RGB | Usage |
|---|---|---|---|
| **ink** | #EEECE9 | 238, 236, 233 | Primary text |
| **graphite** | #D1CFCC | 209, 207, 204 | Secondary text |
| **paper** | #212120 | 33, 33, 32 | Primary background |
| **mist** | #30302E | 48, 48, 46 | Tertiary text, subtle fills |
| **accent** | #FFC824 | 255, 200, 36 | Interactive elements, links, selections |
| **accentSubtle** | accent @ 12% opacity | — | Selection backgrounds, hover fills |
| **background** | #171716 | 23, 23, 22 | Window background |
| **surface** | #1F1F1D | 31, 31, 29 | Card/panel backgrounds |
| **surfaceElevated** | #2B2A28 | 43, 42, 40 | Floating panels, popovers |
| **border** | white @ 12% | — | Primary dividers |
| **borderSubtle** | white @ 6% | — | Secondary dividers |
| **destructive** | systemRed | — | Delete, error |
| **destructiveSubtle** | systemRed @ 12% | — | Destructive backgrounds |
| **warning** | systemYellow | — | Caution |
| **success** | systemGreen | — | Confirmation |
| **glass** | white @ 6% | — | Glass material tint |
| **glassTinted** | accent @ 12% | — | Active glass tint |
| **glassBorder** | white @ 14% | — | Glass edge borders |
| **label** | ink | — | Primary label text |
| **secondaryLabel** | graphite | — | Secondary label text |
| **tertiaryLabel** | mist | — | Tertiary label text |
| **placeholder** | mist @ 60% | — | Placeholder text |

### 2.3 Semantic Tokens — Light Mode

| Token | Hex | RGB | Usage |
|---|---|---|---|
| **ink** | #171716 | 23, 23, 22 | Primary text |
| **graphite** | #40403B | 64, 64, 59 | Secondary text |
| **paper** | #F5F3EF | 245, 243, 239 | Primary background |
| **mist** | #DBD9D3 | 219, 217, 211 | Tertiary text |
| **accent** | #D99E00 | 217, 158, 0 | Interactive (deeper amber for light) |
| **background** | #FAF9F7 | 250, 249, 247 | Window background |
| **surface** | #FFFFFF | 255, 255, 255 | Card/panel backgrounds |
| **surfaceElevated** | #FFFFFF | 255, 255, 255 | Floating panels |
| **border** | #171716 @ 8% | — | Primary dividers |
| **borderSubtle** | #171716 @ 4% | — | Secondary dividers |

### 2.4 Competitive Color Comparison

| App | Background | Surface | Text | Accent |
|---|---|---|---|---|
| **Linear** | #08090a | #0e1012 | #fdfdfd | #5e6ad2 |
| **Vercel** | #111111 | #222222 | #ededed | #0070f3 |
| **Raycast** | #000000 | #1e1e1e | #ffffff | #3b82f6 |
| **GitHub** | #0d1117 | #161b22 | #e6edf3 | #2f81f7 |
| **Hive** | #171716 | #1F1F1D | #EEECE9 | #FFC824 |

**Key difference:** Hive is warmer than all competitors. The near-black has a warm undertone (not pure black, not blue-gray). The amber accent is unique — no other major browser uses warm gold.

### 2.5 Color Rules

1. **Never use pure black (#000000)** for backgrounds. Always use the warm near-black.
2. **Never use pure white (#FFFFFF)** for text in dark mode. Always use the warm near-white.
3. **Accent color is for interactivity only.** Don't use it for decoration.
4. **Destructive actions get systemRed.** No custom reds.
5. **Status indicators must use both color AND shape/icon.** Never color alone.

---

## 3. Typography System

### 3.1 Font Stack

| Context | Font | Variant |
|---|---|---|
| **All chrome text** | SF Pro | Text (≤19pt) or Display (≥20pt) |
| **Code/content** | SF Mono | Monospaced |
| **Brand display** | SF Pro Rounded | Bold only |

**No custom font files.** System fonts only. This ensures Dynamic Type support, sub-pixel rendering, and zero font-loading latency.

### 3.2 Type Scale

| Style | Size | Weight | Line Height | Tracking | Variant | Usage |
|---|---|---|---|---|---|---|
| display1 | 48pt | Light | 56pt | +0.38 | Display | Start page hero |
| display2 | 40pt | Light | 48pt | +0.38 | Display | Start page section |
| brandTitle | 34pt | Bold | 41pt | +0.38 | Rounded | App title in settings |
| largeTitle | 34pt | Regular | 41pt | +0.38 | Display | Window titles |
| title0 | 32pt | Regular | 38pt | +0.38 | Display | — |
| title1 | 28pt | Semibold | 34pt | +0.38 | Display | Page headers |
| title2 | 22pt | Semibold | 28pt | +0.35 | Display | Section headers |
| title3 | 20pt | Semibold | 25pt | +0.38 | Display | Subsection headers |
| headline | 17pt | Semibold | 22pt | -0.41 | Text | List headers |
| body | 17pt | Regular | 22pt | -0.41 | Text | Body text |
| bodyEmphasized | 17pt | Medium | 22pt | -0.41 | Text | Emphasized body |
| callout | 16pt | Regular | 21pt | -0.32 | Text | Secondary body |
| footnote | 13pt | Regular | 18pt | -0.24 | Text | Metadata, timestamps |
| caption1 | 12pt | Regular | 16pt | -0.08 | Text | Labels, badges |
| caption2 | 11pt | Regular | 13pt | 0.0 | Text | Small labels |
| code | 13pt | Regular | 18pt | 0.0 | Mono | Inline code |
| codeSmall | 11pt | Regular | 15pt | 0.0 | Mono | Code annotations |
| chromeTitle | 13pt | Semibold | 18pt | 0.0 | Rounded | Tab titles |
| chromeButton | 13pt | Medium | 18pt | 0.0 | Rounded | Toolbar buttons |
| chromeLabel | 11pt | Medium | 14pt | +0.5 | Rounded | Status labels |
| chromeHeader | 18pt | Semibold | 24pt | 0.0 | Default | Sidebar headers |
| chromeIcon | 14pt | Medium | 18pt | 0.0 | Default | Icon labels |
| chromeBadge | 10pt | Bold | 12pt | 0.0 | Default | Notification badges |
| chromeTabClose | 9pt | Bold | 11pt | 0.0 | Default | Tab close button |
| chromeMicro | 8pt | Regular | 10pt | 0.0 | Default | Footnotes |
| buttonLarge | 24pt | Semibold | 30pt | 0.0 | Default | CTA buttons |

### 3.3 Typography Rules

1. **SF Pro Text for ≤19pt, SF Pro Display for ≥20pt.** The system handles this automatically when using `.system()`.
2. **Rounded variant for chrome only.** It communicates "friendly tool" without being childish.
3. **Negative tracking for body text.** Body and below use negative tracking for tighter reading rhythm.
4. **Zero tracking for chrome.** Chrome text uses zero or positive tracking for legibility at small sizes.
5. **Never hardcode font sizes.** Use the `HiveTypography` enum.
6. **Line height = font size × 1.2–1.4.** Follow the values in the table above exactly.

---

## 4. Spacing & Grid System

### 4.1 Grid

All spacing follows a **4pt base grid**. Every margin, padding, gap, and offset is a multiple of 4.

### 4.2 Spacing Scale

| Token | Value | Usage |
|---|---|---|
| `spacing2` | 2pt | Hairline gaps (icon-to-text in badges) |
| `spacing4` | 4pt | Tight internal padding (tab close button) |
| `spacing8` | 8pt | Standard internal padding (list item padding) |
| `spacing12` | 12pt | Section internal padding (card padding) |
| `spacing16` | 16pt | Standard gap (between sections) |
| `spacing20` | 20pt | Large gap (between major sections) |
| `spacing24` | 24pt | Sidebar section padding |
| `spacing32` | 32pt | Major section separation |
| `spacing48` | 48pt | Page-level margins |
| `spacing64` | 64pt | Hero spacing (start page) |

### 4.3 Corner Radii

| Token | Value | Usage |
|---|---|---|
| `radius4` | 4pt | Badges, small chips |
| `radius6` | 6pt | Buttons, input fields |
| `radius8` | 8pt | Cards, list items |
| `radius10` | 10pt | Tab pills |
| `radius12` | 12pt | Popovers, floating panels |
| `radius16` | 16pt | Sheets, large panels |
| `radius20` | 20pt | Modal dialogs |

### 4.4 Component Dimensions

| Component | Height/Width | Notes |
|---|---|---|
| **Tab pill (horizontal)** | 28–44pt height × variable width (max 200pt) | Density-dependent |
| **Tab row (vertical)** | 32pt height × full sidebar width | Fixed height |
| **Sidebar** | 240–300pt width (resizable) | Min 200pt, max 400pt |
| **Omnibar** | 36pt height × full chrome width | Fixed |
| **Address bar input** | 28pt height | Matches omnibar inner height |
| **Toolbar button** | 26×26pt | Consistent hit target |
| **Context menu item** | 24–28pt height | System standard |
| **Popover** | 250–400pt width | Constrained |
| **Toast** | 250–350pt width × auto height | Stacks max 3 |
| **Tooltip** | Max 250pt width | Auto-dismiss 4s |
| **Split divider** | 4pt wide (hit target) | 1pt visible line |
| **Scrollbar** | 6pt wide (8pt on hover) | Overlay style |

---

## 5. Motion & Animation System

### 5.1 Philosophy

Motion is **functional first**. Every animation communicates spatial relationship, state change, or feedback. Decorative animation is used only for micro-delight moments (e.g., a successful save) and must be < 200ms.

### 5.2 Spring Presets

| Preset | Response | Damping | Usage |
|---|---|---|---|
| **standard** | 0.35s | 0.85 | Most UI transitions (sidebar toggle, section switch) |
| **micro** | 0.18s | 0.90 | Hover states, focus changes, toggle switches |
| **enter** | 0.42s | 0.82 | View entrances (popover, sheet, panel) |
| **exit** | 0.25s | 0.90 | View exits (faster than entrance) |
| **expand** | 0.45s | 0.78 | Panel expand, sidebar reveal, split creation |
| **collapse** | 0.30s | 0.88 | Panel collapse, sidebar hide |
| **pageForward** | 0.40s | 0.82 | Navigate forward |
| **pageBack** | 0.35s | 0.85 | Navigate back |

### 5.3 Duration Presets (Non-Spring)

| Preset | Duration | Usage |
|---|---|---|
| **instant** | 60ms | Opacity toggles, icon swaps |
| **fast** | 120ms | Hover highlights, focus rings |
| **standard** | 200ms | Button press feedback, state changes |
| **slow** | 350ms | Complex layout shifts |
| **expand** | 450ms | Full panel transitions |

### 5.4 Reduced Motion

When `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` is `true`:
- **All springs** → `linear(duration: 0.12)`
- **All durations** → 0.12s
- **No scale effects.** Replace with opacity cross-fades.
- **No parallax.** Remove mouse-tracking depth effects.
- **No stagger.** Items appear simultaneously.

### 5.5 Animation Rules

1. **Entrance speed > exit speed.** Elements should enter quickly (feel responsive) and exit slightly slower (feel deliberate).
2. **Never animate chrome below 60fps.** If a chrome animation drops frames, simplify it or remove it.
3. **Stagger delay = 20ms per item.** For list animations, each item delays 20ms after the previous. Max total stagger = 200ms (cap at 10 items).
4. **Tab switch = instant content swap + 200ms title fade.** The web content swaps immediately. The tab title and favicon cross-fade.
5. **Sidebar toggle = 300ms spring.** Use `expand`/`collapse` presets.
6. **Popover entrance = 150ms ease-out + subtle scale(0.96→1.0).** Fast and confident.
7. **Never use `.transition(.slide)` for chrome.** Always use `.move(edge:)` combined with `.opacity`.

---

## 6. Liquid Glass & Materials

### 6.1 macOS 26 Liquid Glass

On macOS 26 (Tahoe), Hive uses the native Liquid Glass system. Glass is for **navigation layers only** — never for content.

| Modifier | Usage |
|---|---|
| `.glassEffect(.regular)` | Default for toolbars, tab bars |
| `.glassEffect(.regular.tint(color))` | Tinted glass for active states |
| `.glassEffect(.regular.interactive())` | Interactive glass (responds to hover/drag) |
| `GlassEffectContainer` | Wrap multiple glass elements to coordinate sampling |
| `glassEffectID(_:in:)` | Enable morphing transitions between glass elements |

### 6.2 Glass Hierarchy (Top to Bottom)

1. **Floating panels** (popovers, command palette) — `.regular` glass, highest z-index
2. **Sidebar** — `.regular` glass with tinted accent
3. **Tab bar / toolbar** — `.regular` glass
4. **Content** — No glass. Solid background or web content.

### 6.3 Glass Rules

1. **Never stack glass on glass.** A glass sidebar over glass content = muddy hierarchy.
2. **Never use glass on content.** The content area is always opaque or transparent (web content).
3. **Tint with accent only for active/focused states.** Default glass is neutral.
4. **`GlassEffectContainer` when grouping.** Multiple glass elements in the same visual group must share a container.
5. **`glassEffectID` for morphing.** When an element transitions between locations (e.g., tab pill morphing into a split pane header), use `glassEffectID` with a `@Namespace`.
6. **Fallback for pre-macOS 26:** Use `.ultraThinMaterial` with `.background()`.

### 6.4 Pre-macOS 26 Fallback

```swift
if #available(macOS 26.0, *) {
    content.glassEffect(.regular.tint(tint))
} else {
    content.background(.ultraThinMaterial)
}
```

---

## 7. Window Chrome Architecture

### 7.1 The One Rule

**Only ONE tab bar and ONE address bar are visible at any time.** The layout mode determines which tab bar and which chrome elements appear. Never show both horizontal and vertical tabs simultaneously.

### 7.2 Layout Modes

Three layout modes, controlled by `chromeState.tabPosition`:

#### Mode A: Top Tabs (Default — Chrome/Safari style)

```
┌─────────────────────────────────────────┐
│ [Tab] [Tab] [Tab] [+]      [≡] [□] [×] │  ← TabBarView (glass)
├─────────────────────────────────────────┤
│ ◀ ▶ ⟳  [  omnibar input  ]  [🔒] [☆]  │  ← OmniBarView (glass)
├─────────────────────────────────────────┤
│                                         │
│            Content Area                 │  ← WKWebView
│                                         │
└─────────────────────────────────────────┘
```

- **TopChromeView** renders both `TabBarView` and `OmniBarView` in a `VStack`.
- Glass background covers both.
- If sidebar is open, it appears as an overlay on the left (not alongside tabs).

#### Mode B: Vertical Tabs (Arc/Zen style)

```
┌────────┬────────────────────────────────┐
│ [Pin]  │ ◀ ▶ ⟳  [  omnibar  ]  [🔒]   │  ← CompactTopChromeView (glass)
│ [Pin]  ├────────────────────────────────┤
│ [Tab]  │                                │
│ [Tab]  │         Content Area           │  ← WKWebView
│ [Tab]  │                                │
│  ───   │                                │
│ [Space]│                                │
│ [Space]│                                │
└────────┴────────────────────────────────┘
 VerticalTabBarView       Content
 (glass, 48pt collapsed,
  240pt expanded)
```

- **VerticalTabBarView** on the left in an `HSplitView`.
- **CompactTopChromeView** (omnibar only, no tabs) at the top of the content area.
- **Sidebar "Tabs" section is hidden.** The sidebar auto-switches to Bookmarks.
- Vertical tab bar: 48pt collapsed (favicon only), 240pt expanded (favicon + title + close button).
- Hover on collapsed bar → expand with spring animation (expand preset, 0.45s).
- Mouse leaves → collapse after 300ms delay.

#### Mode C: Bottom Tabs (Firefox style)

```
┌─────────────────────────────────────────┐
│ ◀ ▶ ⟳  [  omnibar input  ]  [🔒] [☆]  │  ← CompactTopChromeView (glass)
├─────────────────────────────────────────┤
│                                         │
│            Content Area                 │  ← WKWebView
│                                         │
├─────────────────────────────────────────┤
│ [Tab] [Tab] [Tab] [+]                   │  ← TabBarView ONLY (glass)
└─────────────────────────────────────────┘
```

- **CompactTopChromeView** (omnibar only) at top.
- **TabBarView** at the bottom — **NOT TopChromeView** (which would duplicate the omnibar).
- TabBarView gets its own glass background.

### 7.3 Chrome State

```swift
class ChromeState: ObservableObject {
    @Published var tabPosition: TabPosition = .top      // .top, .vertical, .bottom
    @Published var isSidebarOpen: Bool = false
    @Published var sidebarSection: SidebarSection = .bookmarks
    @Published var density: Density = .standard         // .compact, .standard, .spacious
    @Published var isCollapsed: Bool = false             // Zen mode (all chrome hidden)
    @Published var colorScheme: ColorScheme = .dark
    @Published var reduceMotion: Bool = false
    @Published var topBarComposition: TopBarComposition = .unified  // .unified, .standalone
}
```

### 7.4 Tab Position Transitions

When switching layout modes:
1. **Animate with `matchedGeometryEffect`** for the tab bar container.
2. **Duration:** `expand` spring (0.45s, 0.78 damping).
3. **Content stays in place.** Only chrome rearranges.
4. **Sidebar auto-adjusts:** Vertical tabs → sidebar hides Tabs section. Other modes → sidebar shows all sections.

---

## 8. Tab Bar System

### 8.1 Horizontal Tab Bar (TabBarView)

#### Dimensions

| Density | Tab Height | Tab Min Width | Tab Max Width | Tab Gap | Corner Radius |
|---|---|---|---|---|---|
| **Compact** | 28pt | 60pt | 180pt | 2pt | 8pt |
| **Standard** | 36pt | 80pt | 200pt | 4pt | 10pt |
| **Spacious** | 44pt | 100pt | 220pt | 4pt | 10pt |

#### Tab Pill Anatomy

```
┌─────────────────────────────────┐
│ [🔒] Favicon  Tab Title    [×]  │
└─────────────────────────────────┘
 4pt  16×16   flex    13pt   16×16
      icon          text    close
```

- **Favicon:** 16×16pt, leading 8pt padding from edge.
- **Title:** `chromeTitle` (13pt, Semibold, Rounded). Truncated with ellipsis. Max width = tab width - favicon - close button - 24pt padding.
- **Close button:** 16×16pt hit target (visual icon is 9×9pt). **Hidden by default.** Appears on hover with 120ms fade. Always visible when tab is active.
- **Active tab:** `surface` background, `ink` text, full opacity.
- **Inactive tab:** Transparent background, `secondaryLabel` text, 80% opacity.
- **Hover (inactive):** `surface` background @ 50% opacity, `ink` text, 100% opacity.
- **Pinned tab:** Reduced width (48pt), favicon only, no title. Close button hidden unless hovered.
- **Loading tab:** Thin progress bar (2pt height) at bottom of pill, `accent` color, animated width.

#### Tab Drag & Drop

- **Drag preview:** Small card (120×32pt) with favicon + truncated title + glass background.
- **Drop indicator:** 2pt wide `accent` line between tabs.
- **Ghost:** Original position shows 30% opacity placeholder.
- **Cross-window:** Serializes tab ID via `NSItemProvider`. Target window inserts tab at drop position.
- **Spring into place:** `micro` spring (0.18s) when tab settles.

#### Tab Context Menu

Right-click on tab shows:
- Close Tab
- Close Other Tabs
- Close Tabs to the Right
- ─────────────
- Pin Tab ✓ (toggle)
- Mute Site ✓ (toggle)
- ─────────────
- Duplicate Tab
- Move Tab to Space → (submenu)
- ─────────────
- Copy URL
- Copy Title

### 8.2 Vertical Tab Bar (VerticalTabBarView)

#### Collapsed State (48pt wide)

```
┌──────┐
│ [F]  │  ← Favicon only, 20×20pt centered
│ [F]  │
│ [F]  │
│ ──── │  ← Divider
│ [S]  │  ← Space indicator
│ [S]  │
│ [+]  │  ← New tab button
└──────┘
```

- Each row: 32pt height, favicon 20×20pt centered horizontally.
- On hover: row background changes to `surface` @ 50%.
- **Tooltip on hover** (after 500ms delay): Tab title.
- Space rows at bottom, separated by a `borderSubtle` divider.

#### Expanded State (240pt wide)

```
┌─────────────────────────┐
│ [F] Tab Title      [×]  │
│ [F] Tab Title      [×]  │
│ [F] Tab Title      [×]  │
│ ─────────────────────── │
│ [S] Space Name          │
│ [S] Space Name          │
│ [+] New Tab             │
└─────────────────────────┘
```

- Each row: 32pt height.
- Favicon 16×16pt, title `chromeTitle` (13pt), close button 16×16pt.
- Close button: hidden by default, appears on hover with 120ms fade.
- Pinned tabs: 32pt height, favicon + "📌" indicator, no close button unless hovered.

#### Expand/Collapse Behavior

- **Trigger:** Hover on collapsed bar (not click).
- **Animation:** `expand` spring (0.45s, 0.78 damping).
- **Collapse trigger:** Mouse leaves expanded bar. 300ms delay before collapse.
- **Collapse animation:** `collapse` spring (0.30s, 0.88 damping).
- **If sidebar is open:** Vertical tab bar does NOT collapse (sidebar is the expanded state).

### 8.3 Tab Overflow

When tabs exceed available width:
- **Horizontal:** `ScrollView(.horizontal)` with clip. No fade mask — the scrollbar indicates overflow.
- **Vertical:** `ScrollView(.vertical)` in the tab bar area.
- **Scroll speed:** 1:1 with trackpad/mouse wheel. No acceleration.
- **Keyboard:** `Cmd+Shift+[` and `Cmd+Shift+]` to cycle tabs.

### 8.4 Tab Hover Cards (Future)

When hovering a tab for > 1 second:
- **Card:** 280×180pt, glass background, shows page title + favicon + URL + small page preview.
- **Position:** Below the tab (horizontal) or to the right (vertical).
- **Animation:** `enter` spring (0.42s). Scale 0.96→1.0 + fade in.
- **Dismiss:** Mouse moves away → `exit` animation (0.25s).

---

## 9. Sidebar System

### 9.1 Sections

| Section | Icon | Content |
|---|---|---|
| **Bookmarks** | `bookmark.fill` | Tree of bookmark folders and items |
| **History** | `clock.arrow.circlepath` | Chronological list of visited pages |
| **Reading List** | `eyeglasses` | Saved articles for later |
| **Downloads** | `arrow.down.circle` | Active and completed downloads |
| **Memory** | `brain` | Captured pages and extracted knowledge |

**Note:** "Tabs" section is **hidden** when `tabPosition == .vertical` (to avoid dual tab lists).

### 9.2 Sidebar Dimensions

| Property | Value |
|---|---|
| **Width** | 240–300pt (user resizable) |
| **Min width** | 200pt |
| **Max width** | 400pt |
| **Section header** | 18pt, Semibold, 24pt line height |
| **Section padding** | 16pt top, 8pt bottom, 16pt horizontal |
| **Item height** | 28pt |
| **Item padding** | 8pt horizontal |
| **Item gap** | 2pt between items |

### 9.3 Sidebar Interactions

- **Hover:** Item background → `surface` @ 60%. 120ms transition.
- **Selection:** Item background → `accentSubtle` (accent @ 12%). Text → `accent`.
- **Right-click:** Context menu (native `.contextMenu`).
- **Double-click on bookmark:** Navigate to URL.
- **Drag bookmark:** Reorder or move between folders.
- **Search:** `Cmd+F` in sidebar filters current section.

### 9.4 Sidebar Glass

On macOS 26+: `.glassEffect(.regular.tint(HiveColorToken.glassTinted))`.
On pre-macOS 26: `.background(.ultraThinMaterial)`.

---

## 10. Omnibar & Command Palette

### 10.1 Omnibar (OmniBarView)

The omnibar is the primary input for URLs, searches, and commands.

#### Dimensions
- **Height:** 36pt (full chrome height).
- **Input field:** 28pt height, 6pt corner radius.
- **Background:** `surface` @ 80% opacity. On focus: `surface` @ 100%.
- **Border:** `borderSubtle`. On focus: `accent` @ 30%.

#### Mode Selector

The omnibar has a mode selector on the leading edge:

| Mode | Icon | Behavior |
|---|---|---|
| **Search** | `magnifyingglass` | Default. Searches DuckDuckGo. |
| **URL** | `globe` | Auto-detected when input looks like URL. |
| **Swarm** | `ant.fill` | Routes to Swarm AI chat. |
| **Command** | `terminal` | Triggered by `>` prefix. Browser commands. |

- Mode icon changes automatically as user types.
- Manual mode switch: Click the icon to cycle modes, or use prefix (`>` for command, `@` for Swarm).

#### Address Bar Behavior

1. **On focus (Cmd+L):** Select all text, show suggestions dropdown.
2. **While typing:** Show autocomplete suggestions (history, bookmarks, search suggestions).
3. **Suggestion dropdown:** Max 8 items, 32pt each, glass background.
4. **Selection:** Arrow keys navigate, Enter opens, Escape cancels.
5. **Security indicator:** Lock icon on trailing edge. Green = HTTPS, amber = mixed content, red = HTTP (warning).

### 10.2 Command Palette (Future — Cmd+K)

A universal command interface overlaying the content area.

#### Design
- **Position:** Centered horizontally, 20% from top.
- **Width:** 500pt max.
- **Height:** Auto, max 400pt (scrollable).
- **Background:** `surfaceElevated` + `.glassEffect(.regular)`.
- **Corner radius:** 16pt.
- **Shadow:** 24pt radius, 40% opacity, y-offset 8pt.

#### Input
- **Height:** 44pt.
- **Font:** `body` (17pt).
- **Placeholder:** "Search commands, tabs, history…"
- **Icon:** `magnifyingglass` on leading edge.

#### Results
- **Row height:** 36pt.
- **Sections:** Recently Used, Commands, Tabs, Bookmarks, History.
- **Keyboard:** Up/Down to navigate, Enter to execute, Escape to close.
- **Animation:** Enter with `enter` spring (0.42s), scale 0.96→1.0. Exit with `exit` spring (0.25s).

---

## 11. Content Area

### 11.1 WKWebView Container

- **No padding.** The web content fills the entire content area edge-to-edge.
- **Progress bar:** 2pt height at top of content area, `accent` color. Animated width from 0% to 100%. Disappears 200ms after load completes.
- **Find bar:** Appears at top-right of content area when `Cmd+F` is pressed. 32pt height, glass background, contains search field + match count + prev/next/close buttons.

### 11.2 Content Area Rules

1. **No chrome inside the content area.** The web content is sacred.
2. **Scroll bars:** Overlay style, 6pt wide (8pt on hover).
3. **Text selection:** System default behavior.
4. **Right-click:** Web content's native context menu takes precedence. Browser context menu only for chrome elements.
5. **Zoom:** `Cmd+=` / `Cmd+-` / `Cmd+0`. Zoom level shown in status bar (if visible) for 2 seconds.

---

## 12. Split View System

### 12.1 Split Types

| Type | Layout | Use Case |
|---|---|---|
| **Vertical split** | Left/Right | Compare two pages |
| **Horizontal split** | Top/Bottom | Reference above, work below |
| **Grid split** | 2×2 | Multi-reference research |

### 12.2 Split Creation

- **Keyboard:** `Cmd+Shift+Enter` creates vertical split with current tab.
- **Drag:** Drag a tab to the left/right edge of the content area → drop creates split.
- **Context menu:** "Split Tab Right/Left/Up/Down".

### 12.3 Split Divider

- **Visible width:** 1pt line, `border` color.
- **Hit target:** 4pt wide invisible area around the line.
- **Hover cursor:** `.resizeLeftRight` (vertical split) or `.resizeUpDown` (horizontal split).
- **Drag behavior:** Live resize (no lag). Min pane width: 300pt.
- **Glass divider (macOS 26):** 1pt line with subtle `.glassBorder` color.

### 12.4 Focus Management

- **Click to focus:** Clicking a pane gives it focus (keyboard input, scroll).
- **Keyboard switch:** `Cmd+Shift+[` / `Cmd+Shift+]` cycles focus between panes.
- **Visual indicator:** Focused pane has a subtle `accent` @ 5% border glow on the content edge.
- **Unfocused pane:** Slightly dimmed (5% opacity overlay on the web content — NOT on chrome).

### 12.5 Split Animation

- **Creation:** `expand` spring (0.45s). The new pane slides in from the edge.
- **Removal:** `collapse` spring (0.30s). The remaining pane expands to fill.
- **Resize:** No animation (live drag, 1:1 with mouse).

---

## 13. Download Manager

### 13.1 Toolbar Indicator

- **Icon:** `arrow.down.circle` in toolbar trailing edge.
- **Badge:** Active download count. `chromeBadge` style (10pt, Bold), `accent` background.
- **Progress:** Radial progress ring around the icon (2pt stroke, `accent`).

### 13.2 Downloads Popover

- **Trigger:** Click the download icon.
- **Width:** 350pt.
- **Height:** Auto, max 480pt.
- **Background:** Glass on macOS 26, `.ultraThinMaterial` on older.

#### Download Row

```
┌────────────────────────────────────────┐
│ [PDF] filename.pdf          2.3 MB/s   │
│ ████████░░░░░░░░  45%  — 12.5/28 MB   │
│                              [⏸] [×]  │
└────────────────────────────────────────┘
```

- **Height:** 56pt per active download, 40pt per completed download.
- **File icon:** 32×32pt, file-type-specific icon.
- **File name:** `body` (17pt), truncated.
- **Speed:** `caption1` (12pt), `secondaryLabel`.
- **Progress bar:** 4pt height, `accent` fill, `surface` track. Corner radius: 2pt.
- **Actions:** Pause/Resume (16×16pt), Cancel/Remove (16×16pt).
- **Completed:** Green checkmark icon, "Open" button, "Show in Finder" button.

### 13.3 Drag Out

Users can drag completed downloads directly from the popover to Finder or other apps. The drag preview shows the file icon + name.

### 13.4 Notifications

- **Completion:** System notification via `UNUserNotificationCenter` — only for completed downloads.
- **Failure:** System notification with "Retry" action button.
- **No in-app toast for progress.** The popover IS the progress indicator.

---

## 14. Privacy & Security UI

### 14.1 Security Indicator (Omnibar)

| State | Icon | Color | Tooltip |
|---|---|---|---|
| **HTTPS (valid cert)** | `lock.fill` | `success` | "Connection is secure" |
| **HTTPS (expired cert)** | `lock.open.fill` | `warning` | "Certificate expired" |
| **HTTP** | `exclamationmark.triangle.fill` | `destructive` | "Connection is not secure" |
| **Local file** | `doc.fill` | `secondaryLabel` | "Local file" |
| **About:blank** | — | — | No indicator |

- **Click:** Shows certificate popover with: URL, protocol, certificate authority, expiry date.
- **Popover width:** 300pt.

### 14.2 Tracker Blocker Badge

- **Position:** Trailing edge of omnibar, before bookmark button.
- **Icon:** `shield.fill` when trackers blocked > 0, `shield` otherwise.
- **Badge count:** Number of blocked trackers. `chromeBadge` style.
- **Click:** Popover showing blocked tracker count, categories, and per-site toggle.

### 14.3 Private Mode

- **Visual treatment:** Tab bar uses a distinct dark tint (`paper` instead of `background`). Tab pill has a subtle `destructive` @ 5% border.
- **Icon:** `theatermasks.fill` on each tab and in the omnibar.
- **Start page:** Darker background, "Private Browsing" text, "What this means" explanation.
- **No history, no cookies, no autofill.** The UI reflects this by hiding History section in sidebar.

### 14.4 Permission Prompts

When a site requests camera/microphone/location/notifications:
- **Style:** Sheet (not alert). 400pt wide.
- **Content:** Site URL, requested permission, "Allow" / "Deny" buttons.
- **"Remember" checkbox:** "Remember for this site" — allows persistent allow/deny.
- **Design:** Glass background, clear hierarchy: icon → description → buttons.

---

## 15. Context Menus, Popovers & Tooltips

### 15.1 Context Menus

For chrome elements (tabs, bookmarks, sidebar items):
- **Native `.contextMenu`** on macOS — system handles rendering, dimensions, keyboard shortcuts.
- **Item height:** 24–28pt (system standard).
- **Icons:** SF Symbols, 16pt, leading-aligned.
- **Keyboard shortcuts:** Right-aligned, system font.

For custom context menus (when native is insufficient):
- **Implementation:** Frameless `NSWindow` with SwiftUI content.
- **Background:** Glass on macOS 26, `.ultraThinMaterial` on older.
- **Corner radius:** 10pt.
- **Max width:** 250pt.
- **Appear animation:** 120ms fade + scale 0.95→1.0.
- **Dismiss:** Click outside or Escape.

### 15.2 Popovers

- **Arrow:** Points directly to source element.
- **Max width:** 400pt.
- **Padding:** 16pt.
- **Corner radius:** 12pt.
- **Background:** Glass on macOS 26.
- **Animation:** `enter` spring (0.42s). Scale 0.96→1.0 + fade.

### 15.3 Tooltips

- **Delay:** 500ms hover before showing.
- **Max width:** 250pt.
- **Font:** `caption1` (12pt).
- **Padding:** 6pt vertical, 10pt horizontal.
- **Corner radius:** 6pt.
- **Background:** `surfaceElevated` + subtle shadow.
- **Dismiss:** Mouse moves away (instant).

---

## 16. Drag & Drop System

### 16.1 Tab Reordering

- **Source:** `.draggable(tabID)` on each tab pill.
- **Preview:** 120×32pt card with favicon + title + glass background.
- **Drop indicator:** 2pt `accent` line between tabs.
- **Ghost:** 30% opacity placeholder at original position.
- **Settle animation:** `micro` spring (0.18s).
- **Cancel:** Escape key → tab snaps back with `micro` spring.
- **Cross-window:** Serialize tab via `NSItemProvider`. Target window inserts at drop position.

### 16.2 Bookmark Drag

- **Source:** `.draggable(bookmarkID)` on bookmark items.
- **Drop targets:** Other bookmark items (reorder), folder items (move into), trash (delete).
- **Visual feedback:** Hovered folder highlights with `accentSubtle`.

### 16.3 External Drop

- **URL drop:** Dropping a URL from another app opens it in a new tab.
- **File drop:** Dropping a file opens it with `file://` protocol.
- **Text drop:** Dropping text searches for it.

---

## 17. Notification & Toast System

### 17.1 In-App Toasts

Toasts provide ephemeral feedback within the app window.

#### Design

- **Position:** Top-right of content area (below chrome), floating.
- **Width:** 250–350pt.
- **Height:** Auto (icon + text + optional action).
- **Background:** `surfaceElevated` + glass on macOS 26.
- **Corner radius:** 10pt.
- **Shadow:** 12pt radius, 20% opacity.

#### Anatomy

```
┌──────────────────────────────────────┐
│ [✓] Tab captured to memory    [Undo] │
└──────────────────────────────────────┘
```

- **Icon:** 16pt SF Symbol. Green check for success, red exclamation for error, yellow warning for caution.
- **Text:** `callout` (16pt). Max 2 lines.
- **Action button:** `caption1` (12pt), `accent` color. Optional.

#### Behavior

- **Auto-dismiss:** 3 seconds (base). Formula: 100ms per character, min 2s, max 6s.
- **Entrance:** Slide in from top-right. `enter` spring (0.42s).
- **Exit:** Fade out + slide up. `exit` animation (0.25s).
- **Stacking:** Max 3 visible. New toasts push existing ones down.
- **Dismiss on click:** Click anywhere on toast to dismiss immediately.

### 17.2 System Notifications

For events that matter when the app is in the background:
- **Download complete**
- **Swarm task complete**
- **Memory sync complete**

Use `UNUserNotificationCenter`. Request permission on first relevant action (not on launch).

---

## 18. Error & Empty States

### 18.1 Empty States

Every empty state answers three questions: **What is this? Why is it empty? What can I do?**

#### Start Page (No Tabs)

- **Design:** See [Section 24: Start Page](#24-start-page).
- **Action:** "Open a new tab" + grid of frequently visited sites.

#### Bookmarks (Empty)

```
        [bookmark icon, 48pt, secondaryLabel]
        
        No bookmarks yet
        
        Bookmark pages you want to revisit.
        Use ⌘D or click the ☆ in the address bar.
        
        [Import Bookmarks…]
```

#### History (Empty)

```
        [clock icon, 48pt, secondaryLabel]
        
        No history
        
        Pages you visit will appear here.
        Your history stays on this device.
```

#### Memory (Empty)

```
        [brain icon, 48pt, secondaryLabel]
        
        No memories captured
        
        Capture pages to build your knowledge base.
        Use ⌘⇧E or the capture button in the toolbar.
        
        [Capture Current Page]
```

#### Downloads (Empty)

```
        [arrow.down.circle icon, 48pt, secondaryLabel]
        
        No downloads
        
        Files you download will appear here.
```

### 18.2 Error States

#### Network Error (WKWebView)

- **Design:** Custom error page rendered in the WKWebView.
- **Content:** "Safari-style" clean error: icon, message, URL, "Try Again" button.
- **Message:** "Safari can't open the page." / "Hive can't connect to [hostname]."
- **Action:** Prominent "Try Again" button (`accent` background). "Go Back" secondary button.

#### WebKit Process Crash

- **Delegate:** `webViewWebContentProcessDidTerminate`.
- **Action:** Automatically reload the page. If crash persists (3 consecutive), show native error overlay:
  ```
  This page has crashed.
  [Reload Page]  [Go Back]
  ```

#### Offline

- **Banner:** 32pt height, `warning` background, below chrome.
- **Text:** "You're offline. Some features may be unavailable."
- **Dismiss:** Auto-dismiss when back online.

### 18.3 Loading States

- **Page loading:** Progress bar (2pt, `accent`) at top of content area.
- **Content loading (sidebar, settings):** Skeleton screens — gray placeholder bars matching the expected layout.
- **Never use spinners for chrome.** Use skeleton screens or progress bars.

---

## 19. Onboarding

### 19.1 Philosophy

Onboarding is **embedded in the app**, not a separate wizard. It teaches by doing, not by explaining.

### 19.2 First Launch Flow (3 steps)

#### Step 1: Welcome

- **Design:** Full-window overlay with glass background.
- **Content:** "Welcome to Hive" (brandTitle, 34pt, Bold, Rounded).
- **Subtitle:** "The browser for people who work in tabs." (body, 17pt).
- **Action:** "Get Started" button (accent background, white text).
- **Animation:** Title fades in (200ms), subtitle fades in (200ms, 200ms delay), button fades in (200ms, 400ms delay).

#### Step 2: Import

- **Design:** Import dialog embedded in the onboarding flow.
- **Content:** "Bring your stuff" — checkboxes for Bookmarks, History, Passwords.
- **Sources:** Chrome, Safari, Firefox, Edge (auto-detected).
- **Action:** "Import" button. Progress bar during import.
- **Skip:** "I'll do this later" link.

#### Step 3: Choose Your Layout

- **Design:** Three visual previews of layout modes (Top Tabs, Vertical Tabs, Bottom Tabs).
- **Interaction:** Click a preview to select it. Selected preview has `accent` border.
- **Action:** "Start Browsing" button.
- **Skip:** "I'll customize later" link.

### 19.3 Post-Onboarding

- **First tab opens to start page** (see Section 24).
- **Subtle keyboard hint:** "Press ⌘K to open the command palette" toast, shown once.
- **No further interruptions.** The user is browsing.

---

## 20. Settings

### 20.1 Settings Window

- **Style:** Separate window (not sheet). 600×500pt default size.
- **Sidebar:** Sections with icons (system `Settings` style).
- **Content:** Right pane with form controls.

### 20.2 Sections

| Section | Icon | Content |
|---|---|---|
| **General** | `gear` | Default browser, startup behavior, download folder |
| **Appearance** | `paintbrush` | Theme, accent color, density, layout mode |
| **Privacy** | `lock.shield` | Tracker blocking, cookies, permissions |
| **Search** | `magnifyingglass` | Default search engine, suggestions |
| **Spaces** | `square.grid.2x2` | Manage spaces and workspaces |
| **Keyboard** | `keyboard` | Shortcut customization |
| **Profiles** | `person.2` | Manage browser profiles |
| **Advanced** | `gearshape.2` | Developer options, experimental features |

### 20.3 Settings Controls

- **Toggle:** System `Toggle` with labels.
- **Picker:** System `Picker` with segmented or menu style.
- **Text field:** 28pt height, 6pt radius, `surface` background.
- **Color picker:** System `ColorPicker`.
- **Slider:** System `Slider` for numerical ranges.

---

## 21. Keyboard Shortcuts

### 21.1 Core Navigation

| Shortcut | Action |
|---|---|
| `⌘T` | New tab |
| `⌘W` | Close tab |
| `⌘⇧T` | Reopen closed tab |
| `⌘L` | Focus address bar |
| `⌘K` | Command palette |
| `⌘⇧J` | Open Swarm workspace |
| `⌘⇧E` | Capture page to memory |
| `⌘[` | Navigate back |
| `⌘]` | Navigate forward |
| `⌘R` | Reload |
| `⌘⇧R` | Hard reload (bypass cache) |
| `⌘F` | Find in page |
| `⌘D` | Bookmark page |
| `⌘⇧S` | Toggle sidebar |
| `⌘⇧F` | Toggle full screen |
| `⌘,` | Open settings |

### 21.2 Tab Management

| Shortcut | Action |
|---|---|
| `⌘⇧[` | Previous tab |
| `⌘⇧]` | Next tab |
| `⌘1`–`⌘9` | Switch to tab 1–9 |
| `⌘9` | Switch to last tab |
| `⌘⇧↩` | Split tab (vertical) |
| `⌘⌥↩` | Split tab (horizontal) |
| `⌘⇧P` | Toggle private mode |

### 21.3 Layout

| Shortcut | Action |
|---|---|
| `⌘⇧\` | Toggle sidebar |
| `⌘⇧L` | Cycle layout mode (top → vertical → bottom) |
| `⌘⇧M` | Minimize to menu bar |
| `⌘⌥I` | Toggle inspector (dev tools) |

### 21.4 Keyboard Design Rules

1. **Single-key shortcuts only in command mode.** Regular mode uses `⌘` modifier.
2. **Discoverability:** All shortcuts appear in menu bar items.
3. **Customization:** Users can rebind shortcuts in Settings > Keyboard.
4. **Conflict detection:** Warn if a shortcut conflicts with macOS system shortcuts.

---

## 22. Accessibility

### 22.1 VoiceOver

- **Tab bar:** Each tab is a radio button (`NSAccessibilityRadioButtonRole`). Selected state announced.
- **Sidebar:** Each item has `accessibilityLabel` = item title. Section headers announced as headings.
- **Omnibar:** `accessibilityLabel` = "Address bar". Value = current URL. Placeholder = "Search or enter URL".
- **Progress bar:** `accessibilityValue` = "Loading 45%".

### 22.2 Reduce Motion

- All springs → `linear(duration: 0.12)`.
- All scale effects → opacity cross-fades.
- No stagger. Items appear simultaneously.
- No parallax or mouse-tracking effects.
- Use `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`.

### 22.3 Increase Contrast

- All border colors increase opacity by 50%.
- Text colors increase to maximum contrast (use `ink` for all text).
- Selection background increases to 20% opacity.

### 22.4 Reduce Transparency

- All glass effects → solid `surface` background.
- All material effects → solid `background` color.
- Use `NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency`.

### 22.5 Keyboard Full Access

- Every interactive element reachable via Tab key.
- Focus ring: System standard (2pt, `accent`, offset 2pt).
- Custom controls implement `nextKeyView` / `previousKeyView`.

### 22.6 Dynamic Type

- Use `HiveTypography` for all text (never hardcoded sizes).
- Sidebar and list items respect system text size.
- Chrome text has a minimum size of 11pt (doesn't shrink below).

### 22.7 Color Blindness

- Status indicators use both color AND shape/icon.
- HTTPS lock icon (shape) + green color (color).
- Error uses `exclamationmark.triangle` (shape) + red (color).
- Never rely on color alone.

---

## 23. Theme System

### 23.1 Built-in Themes

| Theme | Background | Surface | Accent | Notes |
|---|---|---|---|---|
| **Hive Dark** (default) | #171716 | #1F1F1D | #FFC824 | Warm near-black |
| **Hive Light** | #FAF9F7 | #FFFFFF | #D99E00 | Warm near-white |
| **System** | Follows OS | Follows OS | Follows OS | Respects system appearance |

### 23.2 Custom Accent Colors

Users can choose any accent color. The system automatically adjusts:
- **Dark mode:** Accent at 100% saturation for interactive elements, 12% for subtle fills.
- **Light mode:** Accent at 85% saturation for interactive elements, 6% for subtle fills.
- **Contrast check:** If accent doesn't meet 4.5:1 contrast ratio against background, auto-darken/lighten.

### 23.3 Dynamic Theme (Future)

Like SigmaOS "Magic Themes":
- Extract dominant color from page's `<meta name="theme-color">` or favicon.
- Apply as subtle tint to tab bar and sidebar.
- Only affects chrome, never content.
- User opt-in (Settings > Appearance > "Match page color").

---

## 24. Start Page

### 24.1 Layout

```
┌─────────────────────────────────────────┐
│                                         │
│           🐝 Hive                       │  ← brandTitle (34pt, Bold, Rounded)
│                                         │
│     ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐   │
│     │ FV  │ │ FV  │ │ FV  │ │ FV  │   │  ← Frequently visited sites
│     │     │ │     │ │     │ │     │   │     80×80pt cards, glass background
│     │Name │ │Name │ │Name │ │Name │   │
│     └─────┘ └─────┘ └─────┘ └─────┘   │
│                                         │
│     Bookmarks          Reading List     │  ← Two-column layout below
│     ┌──────────┐       ┌──────────┐    │
│     │ ...      │       │ ...      │    │
│     └──────────┘       └──────────┘    │
│                                         │
└─────────────────────────────────────────┘
```

### 24.2 Start Page Design

- **Background:** `background` color (not glass, not material).
- **Logo:** "🐝 Hive" in `brandTitle` style (34pt, Bold, Rounded). Centered.
- **Frequently Visited:** Grid of 4–8 cards. 80×80pt each. Favicon 32×32pt centered, site name below in `caption1`. Card background: `surface`. Corner radius: 10pt. Hover: `surfaceElevated` + subtle scale 1.02.
- **Bookmarks section:** Left column. List of top 10 bookmarks.
- **Reading List section:** Right column. List of top 10 reading list items.
- **Search:** Clicking anywhere on the start page focuses the omnibar.
- **No AI suggestions, no news feed, no ads.** The start page is a clean launchpad.

---

## 25. Reader Mode

### 25.1 Activation

- **Button:** `doc.plaintext` icon in omnibar trailing edge (only visible when reader mode is available).
- **Keyboard:** `⌘⇧R` (when not conflicting with hard reload).

### 25.2 Design

- **Background:** `paper` color (warm near-black in dark, warm near-white in light).
- **Text:** `body` (17pt), `ink` color. Max width: 680pt, centered.
- **Headings:** Follow the type scale (title1 → caption1).
- **Images:** Max width: 680pt, corner radius: 8pt.
- **Links:** `accent` color, underline on hover.
- **Code blocks:** `surface` background, `code` font (13pt, Mono).
- **Exit:** Click the reader mode button again, or navigate away.

### 25.3 Read Aloud

- **Button:** `speaker.wave.2` icon in reader mode toolbar.
- **Engine:** `AVSpeechSynthesizer`.
- **Controls:** Play/Pause, Stop. Speed: 0.5x, 1.0x, 1.5x, 2.0x.
- **Highlight:** Current sentence highlighted with `accentSubtle` background.

---

## 26. Swarm Workspace

### 26.1 Trigger

- **Keyboard:** `⌘⇧J` from anywhere.
- **Sidebar:** Click "Swarm" section.
- **Global hotkey:** `⌘⌘` (double-tap Cmd) from any app (via `GlobalHotkeyController`).

### 26.2 Layout

The Swarm workspace occupies the full content area (replaces web content).

```
┌─────────────────────────────────────────┐
│ [Chat] [Research] [Wiki] [Code]         │  ← Mode tabs
├─────────────────────────────────────────┤
│                                         │
│         Chat / Research / Wiki          │  ← Content area
│         (depends on selected mode)      │
│                                         │
├─────────────────────────────────────────┤
│ [Input field                        ]   │  ← Input bar
│ [📎] [Model: GPT-5] [Send ⌘↩]          │
└─────────────────────────────────────────┘
```

### 26.3 Chat Mode

- **Messages:** Left-aligned (AI) and right-aligned (user).
- **AI messages:** `surface` background, `body` font, markdown rendering.
- **User messages:** `accentSubtle` background, `body` font.
- **Code blocks:** `surface` background, `code` font, copy button on hover.
- **Streaming:** Character-by-character with cursor blink animation.

### 26.4 Research Mode

- **Input:** Question field.
- **Output:** Cited answer with source links.
- **Sources:** List of URLs with titles and snippets. Click to open in browser.
- **Format:** Structured markdown with headers, bullet points, and inline citations.

---

## 27. Icons & Imagery

### 27.1 Icon System

- **SF Symbols only.** No custom icon files.
- **Weight:** Medium for chrome, Regular for content.
- **Size:** 14pt for inline, 16pt for buttons, 20pt for section headers, 32pt for empty states, 48pt for hero.
- **Rendering:** Hierarchical color (primary icon + secondary detail).

### 27.2 Icon Usage Table

| Context | SF Symbol | Size | Weight |
|---|---|---|---|
| New tab | `plus` | 13pt | Semibold |
| Close tab | `xmark` | 9pt | Bold |
| Back | `chevron.left` | 14pt | Medium |
| Forward | `chevron.right` | 14pt | Medium |
| Reload | `arrow.clockwise` | 14pt | Medium |
| Lock (secure) | `lock.fill` | 12pt | Regular |
| Lock (insecure) | `lock.open.fill` | 12pt | Regular |
| Bookmark | `star` / `star.fill` | 14pt | Regular |
| Sidebar | `sidebar.left` | 14pt | Medium |
| Downloads | `arrow.down.circle` | 14pt | Regular |
| Settings | `gearshape` | 14pt | Regular |
| Search | `magnifyingglass` | 14pt | Medium |
| Reader | `doc.plaintext` | 14pt | Regular |
| Private | `theatermasks.fill` | 14pt | Regular |
| Swarm | `ant.fill` | 14pt | Medium |
| Memory | `brain` | 14pt | Regular |
| Pin tab | `pin.fill` | 10pt | Regular |
| Mute | `speaker.slash.fill` | 12pt | Regular |
| Split | `rectangle.split.2x1` | 14pt | Regular |
| Capture | `camera.viewfinder` | 14pt | Regular |

### 27.3 Imagery Rules

1. **No stock photos.** No placeholder images.
2. **No emoji in chrome.** Emoji is fine in user content (bookmarks, notes).
3. **Favicons:** 16×16pt for tabs, 32×32pt for start page cards. Always show the site's favicon.
4. **No gradients on icons.** Flat, solid color only.
5. **No custom illustrations.** If an empty state needs visual interest, use a large SF Symbol at 48pt.

---

## 28. Performance Budget

### 28.1 Frame Rate

| Component | Target | Minimum |
|---|---|---|
| **Chrome animations** | 60fps | 60fps (non-negotiable) |
| **Content scroll** | 120fps (ProMotion) | 60fps |
| **Split resize** | 60fps | 30fps |
| **Tab drag** | 60fps | 60fps |

### 28.2 Memory

| Component | Budget |
|---|---|
| **Chrome (SwiftUI views)** | < 50MB |
| **Per-tab WKWebView** | < 300MB (typical), < 500MB (max) |
| **Hibernated tab** | < 1MB (URL + interactionState only) |
| **Total (10 tabs)** | < 2GB |

### 28.3 Launch Time

| Metric | Target |
|---|---|
| **Cold launch to interactive** | < 1.5s |
| **Warm launch to interactive** | < 0.5s |
| **New tab open** | < 200ms |
| **Tab switch** | < 100ms |

### 28.4 Performance Rules

1. **Aggressive tab hibernation.** Background tabs > 10 minutes get hibernated (WKWebView removed from hierarchy, interactionState serialized).
2. **Process pool sharing.** All tabs share one `WKProcessPool` for cookie/session sharing.
3. **Content blockers compiled at launch.** `WKContentRuleList` compiled once, cached.
4. **No synchronous main-thread work during animations.** All data loading is async.
5. **`drawingGroup()` for complex static chrome.** Flatten complex view hierarchies into a single layer.

---

## 29. Anti-Slop Rules

### 29.1 Visual Anti-Slop

| # | Rule | Rationale |
|---|---|---|
| 1 | No gradient text | Instant AI tell. Text is always solid color. |
| 2 | No numbered sections ("01", "02") | Corporate template energy. |
| 3 | No symmetrical card grids | Creates visual monotony. Use asymmetric layouts. |
| 4 | No glass on content | Glass is for navigation layers. Content is sacred. |
| 5 | No AI sparkle icons ✨ | AI is embedded, not branded. |
| 6 | No default blue accents | Hive uses warm amber. Blue is for links only. |
| 7 | No centered layouts (except start page) | Left-align for reading. Center for hero only. |
| 8 | No fade-in on chrome | Chrome should be instant. Content may fade. |
| 9 | No bouncy springs | Use critically damped springs (damping ≥ 0.78). |
| 10 | No pure black backgrounds | Always warm near-black (#171716). |

### 29.2 Interaction Anti-Slop

| # | Rule | Rationale |
|---|---|---|
| 1 | No loading spinners in chrome | Use skeleton screens or progress bars. |
| 2 | No modal interruptions | Sheets for important actions. Alerts for destructive only. |
| 3 | No tooltips explaining obvious things | Tooltips only for truncated text or non-obvious icons. |
| 4 | No confirmation dialogs for reversible actions | Undo toasts instead. |
| 5 | No animation for animation's sake | Every animation communicates something. |
| 6 | No keyboard shortcut conflicts | Detect and warn. |
| 7 | No double-click to select (in chrome) | Single click for everything. |
| 8 | No hover-to-click delay | Hover feedback is instant (120ms transition). |
| 9 | No scroll hijacking | Web content scrolls natively. |
| 10 | No auto-play anything | User initiates all media. |

### 29.3 Copy Anti-Slop

| # | Rule | Rationale |
|---|---|---|
| 1 | No "Oops!" or "Uh-oh!" in errors | Professional tone. State the problem and solution. |
| 2 | No "Pro" or "Premium" labels | Hive doesn't gate features. |
| 3 | No "AI-powered" descriptions | AI is a capability, not a brand. |
| 4 | No exclamation marks in UI copy | Calm confidence. |
| 5 | No "Welcome back, [Name]!" | Respect the user's time. |
| 6 | No loading messages ("Crunching data…") | Show progress, not personality. |
| 7 | Error messages state problem + solution | Never just the problem. |
| 8 | Button labels are verbs | "Save" not "OK". "Delete" not "Yes". |
| 9 | No "Learn more" links without context | Explain inline or don't link. |
| 10 | No placeholder text in production | Every field has a real placeholder or is empty. |

---

## 30. Layout Modes — Detailed Spec

### 30.1 Mode A: Top Tabs (Default)

**Target users:** Chrome/Safari switchers. Familiar, conventional.

```
Chrome layer (glass):
┌─────────────────────────────────────────┐
│ [TabBarView — horizontal tab pills]     │  Height: density-dependent (28/36/44pt)
├─────────────────────────────────────────┤
│ [OmniBarView — address + controls]      │  Height: 36pt
└─────────────────────────────────────────┘

Content layer:
┌─────────────────────────────────────────┐
│                                         │
│              WKWebView                  │
│                                         │
└─────────────────────────────────────────┘
```

**Sidebar:** Overlays content from left edge. Does NOT push content. 240–300pt wide.
**Inspector:** Overlays content from right edge. Does NOT push content. 320pt wide.

### 30.2 Mode B: Vertical Tabs

**Target users:** Arc/Zen users. Power users with many tabs.

```
┌──────────┬──────────────────────────────┐
│ Vertical │ [CompactTopChromeView]       │  ← Omnibar only
│ Tab Bar  ├──────────────────────────────┤
│          │                              │
│  48pt    │         WKWebView            │
│ (hover   │                              │
│  →240pt) │                              │
│          │                              │
└──────────┴──────────────────────────────┘
```

**Sidebar:** Hidden by default. Can be toggled with `⌘⇧S` to show Bookmarks/History/etc. in a panel overlaying the content area (NOT alongside the vertical tab bar).
**Key rule:** Sidebar "Tabs" section is filtered out. No duplicate tab lists.

### 30.3 Mode C: Bottom Tabs

**Target users:** Firefox users. Bottom tabs maximize vertical content space.

```
┌─────────────────────────────────────────┐
│ [CompactTopChromeView — omnibar]        │  ← Omnibar only (no tabs)
├─────────────────────────────────────────┤
│                                         │
│              WKWebView                  │
│                                         │
├─────────────────────────────────────────┤
│ [TabBarView — horizontal tab pills]     │  ← TabBarView ONLY, not TopChromeView
└─────────────────────────────────────────┘
```

**Sidebar:** Same as Mode A — overlays from left.
**Key rule:** Bottom uses `TabBarView` directly, NOT `TopChromeView`. This prevents the dual-Omnibar bug.

### 30.4 Layout Transition Animation

When switching between modes:
1. Tab bar morphs position with `matchedGeometryEffect`.
2. Omnibar stays at top (in all modes, it's at the top of the content area or the top of the window).
3. Duration: `expand` spring (0.45s, 0.78 damping).
4. Content stays in place. Only chrome rearranges.
5. Sidebar auto-adjusts its available sections.

---

## Appendix A: Existing Codebase Audit

### Current Design Tokens (HiveColorToken.swift)

**Strengths:**
- Semantic token system is correct.
- Dark-first approach is correct.
- Warm near-black (not pure black) is correct.
- Single accent color (amber) is correct.
- Glass tokens exist.

**Gaps:**
- No `interactive` token for hover/active states (currently hardcoded in views).
- No `focus` token for focus rings.
- Deprecated subsystem colors (`intelligenceBlue`, `amber`, `teal`, etc.) still in the enum — should be removed.
- `hiveColor` extension uses `.light` hardcoded — should respect environment.

### Current Typography (HiveTypography.swift)

**Strengths:**
- Comprehensive scale covers all use cases.
- Chrome-specific styles (chromeTitle, chromeButton, etc.) are good.
- Rounded variant for chrome is correct.

**Gaps:**
- Tracking values for chrome styles are all 0.0 — should match Apple's tracking tables.
- No `bodySmall` style between `body` and `callout`.
- `buttonLarge` at 24pt is unusually large — verify against HIG.

### Current Motion (HiveEasing.swift)

**Strengths:**
- Spring presets are well-tuned.
- Reduced motion fallback exists.
- `HiveMotion` utility is clean.

**Gaps:**
- No stagger utility for list animations.
- No `matchedGeometryEffect` wrapper.
- `glassTransition` is defined but not used in views.

---

## Appendix B: Reference Color Values (Competitors)

### Linear Dark Mode
```
background: #08090a
surface:    #0e1012
text:       #fdfdfd
secondary:  #babbc5
tertiary:   #70717b
border:     #1f2125
accent:     #5e6ad2
success:    #50c793
warning:    #f6b451
error:      #ed5f5f
```

### Vercel (Geist) Dark Mode
```
background: #111111
surface:    #222222
text:       #ededed
secondary:  #888888
border:     #333333
accent:     #0070f3
success:    #00703c
warning:    #af6a00
error:      #e00
```

### Raycast Dark Mode
```
background: #000000
surface:    #1e1e1e
text:       #ffffff
secondary:  #999999
border:     #333333
accent:     #3b82f6
success:    #22c55e
warning:    #f59e0b
error:      #ef4444
```

### GitHub (Primer) Dark Mode
```
background: #0d1117
surface:    #161b22
text:       #e6edf3
secondary:  #8b949e
border:     #30363d
accent:     #2f81f7
success:    #3fb950
warning:    #d29922
error:      #f85149
```

### Figma Dark Mode
```
background: #1e1e1e
surface:    #2c2c2c
text:       #e5e5e5
secondary:  #b3b3b3
border:     #444444
accent:     #0d99ff
success:    #00b87c
warning:    #ffa629
error:      #f24822
```

---

## Appendix C: macOS 26 Liquid Glass API Reference

### glassEffect Modifier

```swift
// Default glass (capsule shape)
.glassEffect()

// Custom shape
.glassEffect(.regular, in: .rect(cornerRadius: 12))

// Tinted glass
.glassEffect(.regular.tint(.yellow.opacity(0.1)))

// Interactive glass (responds to hover/drag)
.glassEffect(.regular.interactive())

// Clear variant (for media-rich content)
.glassEffect(.clear)
```

### GlassEffectContainer

```swift
GlassEffectContainer {
    HStack {
        Text("Tab 1").glassEffect()
        Text("Tab 2").glassEffect()
    }
}
// Elements share sampling region — no visual seams
```

### Morphing Transitions

```swift
@Namespace var namespace

// Source
Circle()
    .glassEffect(.regular.interactive(), in: .circle)
    .glassEffectID("tab", in: namespace)

// Destination
RoundedRectangle(cornerRadius: 12)
    .glassEffect(.regular, in: .rect(cornerRadius: 12))
    .glassEffectID("tab", in: namespace)
// SwiftUI morphs between the two shapes
```

---

## Appendix D: WKWebView Tab Management

### Tab Hibernation

```swift
// Serialize state before hibernation
let state = try? webView.interactionState as? Data
store.saveState(url: webView.url, state: state, forTab: tabID)

// Hibernate: remove from view hierarchy
webView.removeFromSuperview()
webView = nil

// Restore
let newWebView = WKWebView()
newWebView.interactionState = storedState
// Attach to view hierarchy
```

### Process Crash Recovery

```swift
func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    // Attempt reload
    if crashCount[tabID] ?? 0 < 3 {
        crashCount[tabID, default: 0] += 1
        webView.reload()
    } else {
        // Show error overlay
        showErrorOverlay(for: tabID)
    }
}
```

### Content Blockers

```swift
// Compile once at launch
WKContentRuleListStore.default().compileContentRuleList(
    forIdentifier: "HiveBlocker",
    encodedContentRuleList: rulesJSON
) { list, error in
    // Store compiled list
    self.contentRuleList = list
}

// Apply to each web view
webView.configuration.userContentController.add(contentRuleList!)
```

---

---

## Appendix E: WKWebView Find-in-Page API

### API Surface

```swift
// Search forward
webView.find(query, configuration: WKFindConfiguration()) { result in
    // result.matchFound: Bool
}

// Search backward
let config = WKFindConfiguration()
config.backwards = true
config.wrapsAround = true
webView.find(query, configuration: config) { _ in }

// Clear highlights
webView.find("", configuration: WKFindConfiguration()) { _ in }
```

### Key Facts
- WebKit handles highlighting automatically — no JS injection needed.
- `WKFindResult` has `matchFound: Bool` only — no total match count.
- Navigation: call `find` again with `backwards = false` (next) or `backwards = true` (previous).
- Debounce input by 200–300ms to avoid excessive re-highlighting.
- To clear: call `find` with empty string.

---

## Appendix F: WKWebsiteDataStore Cookie & Data Management

### Data Types

`WKWebsiteDataStore.allWebsiteDataTypes()` includes:
- `diskCache`, `memoryCache`, `offlineWebApplicationCache`
- `localStorage`, `sessionStorage`, `indexedDBDatabases`
- `cookies`, `webSQLDatabases`, `javaScriptClassLoader`

### Key Operations

```swift
// Clear all data
let store = WKWebsiteDataStore.default()
store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                 modifiedSince: .distantPast) {}

// Clear data for specific domain
store.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
    let filtered = records.filter { $0.displayName.contains("example.com") }
    store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                     for: filtered) {}
}

// Cookie management
store.httpCookieStore.getAllCookies { cookies in /* ... */ }
store.httpCookieStore.setCookie(cookie) {}
store.httpCookieStore.deleteCookie(cookie) {}
```

### Private Browsing
- `WKWebsiteDataStore.nonPersistent()` — in-memory only, auto-clears on dealloc.
- WebKit ITP handles third-party cookie blocking automatically.

---

## Appendix G: NSWindow Management for Browsers

### Architecture Recommendation
**Do not use NSDocument for a browser.** Use a custom `BrowserSessionManager`:
- `NSWindow` + `NSWindowController` for each window.
- AppKit's native window tabbing (`window.tabbingMode = .preferred`).
- JSON/SQLite persistence in `~/Library/Application Support/Hive/`.

### Key Patterns

```swift
// Frameless floating panel (for command palette)
let panel = NSPanel(contentRect: .zero,
    styleMask: [.nonactivatingPanel, .borderless],
    backing: .buffered, defer: false)
panel.isFloatingPanel = true

// Custom title bar
window.titleVisibility = .hidden
window.titlebarAppearsTransparent = true

// Always-on-top
window.level = .floating

// Position at mouse cursor
let mouseLoc = NSEvent.mouseLocation
window.setFrame(NSRect(x: mouseLoc.x - w/2, y: mouseLoc.y - h/2,
                        width: w, height: h), display: true)

// Keyboard event monitoring
NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
    // Handle keys, return nil to consume
    return event
}

// Animate window
NSAnimationContext.runAnimationGroup({ ctx in
    ctx.duration = 0.25
    window.animator().setFrame(newRect, display: true)
})
```

---

## Appendix H: Content Blocker Rule Syntax

### JSON Format

```json
[
  {
    "trigger": {
      "url-filter": ".*tracker\\.com/.*",
      "resource-type": ["script", "image"],
      "load-type": ["third-party"]
    },
    "action": { "type": "block" }
  },
  {
    "trigger": { "url-filter": ".*" },
    "action": {
      "type": "css-display-none",
      "selector": ".cookie-banner, #newsletter-popup"
    }
  }
]
```

### Trigger Fields
- `url-filter` (required): Regex pattern matching resource URL.
- `url-filter-is-case-sensitive`: Bool, default false.
- `resource-type`: Array of `image`, `script`, `font`, `style-sheet`, `document`, `raw`, `svg-document`, `media`, `popup`.
- `if-domain` / `unless-domain`: Domain filters (mutually exclusive).
- `load-type`: `first-party` or `third-party`.
- `if-top-url`: Match resources within specific document URLs.

### Action Types
- `block`: Abort resource load.
- `css-display-none`: Hide elements (requires `selector` field).
- `block-cookies`: Strip cookies from request.
- `ignore-previous-rules`: Skip all preceding rules.

### Performance
- No hard rule count limit, but avoid complex regex (minimize `*`, `+`, `?`).
- Compile once at launch via `WKContentRuleListStore.default().compileContentRuleList`.
- Apply to each webview: `webView.configuration.userContentController.add(list)`.

---

## Appendix I: Safari Tab Overview Design

### Visual Design
- Tabs displayed as **thumbnail card grid** using `LazyVGrid` with adaptive `GridItem`.
- Each card: page preview thumbnail + page title + favicon.
- Active tab highlighted prominently.
- Hover reveals close button (`×`) on card corner.

### Animation
- **Enter:** Current tab scales down into grid position. Grid assembles with matched geometry.
- **Exit:** Selected card zooms into full-page view. Reverse of enter.
- Use `@Namespace` + `.matchedGeometryEffect(id:in:)` for morphing.

### Thumbnail Generation
- Rendered by off-screen WebCore engine, cached to disk.
- Updated when tab is inactive and page changes.
- Use `.onAppear` / `.onDisappear` to trigger/pause generation.

### Keyboard
- `Cmd+Shift+\` to toggle overview.
- Arrow keys to navigate grid.
- Enter to select. Escape to dismiss.

---

## Appendix J: Linear Animation System Deep Dive

### Technology Stack
- **Animation library:** Framer Motion (React).
- **State management:** MobX (instant reactivity, no animation lag from state sync).
- **Internal dev tools:** Real-time spring parameter tweaking via feature flags.

### Spring Parameters
- **Stiffness:** 200–400 (high for immediacy).
- **Damping:** 20–30 (high to prevent oscillation).
- **Mass:** 1 (simplifies physics).
- Philosophy: critically damped or slightly under-damped. "Weighted, not bouncy."

### Interaction Patterns
- **List add/remove:** `AnimatePresence` + `layout` prop. All neighboring items auto-interpolate positions.
- **Command palette:** Scale 0.95→1.0 + opacity fade. High stiffness for instant arrival.
- **Sidebar expand:** `height: auto` via `layout` prop. Spring transition for "mass" feel.
- **Modal:** Scale-up + backdrop blur. Backdrop starts slightly before modal for layered effect.
- **Skeleton loading:** CSS `linear-gradient` panning. Off-main-thread for zero stutter.
- **Hover cards:** Delayed trigger, fade-in + slide-up, high-damping spring.
- **Toast stacking:** Absolute-positioned container. New toasts push existing ones down via `layout` animation.

---

## Appendix K: App Sandbox Entitlements for Browser

### Required Entitlements
- `com.apple.security.app-sandbox` — Enables sandbox.
- `com.apple.security.network.client` — Outbound HTTP/HTTPS connections.
- `com.apple.security.files.user-selected.read-write` — NSOpenPanel/NSSavePanel file access.
- `com.apple.security.files.downloads.read-write` — Downloads folder access.

### Key Facts
- WKWebView runs in separate "Web Content" process within sandbox.
- Downloads require `NSSavePanel` or Downloads entitlement.
- `file://` URLs limited to app container + user-selected files + Security-Scoped Bookmarks.
- Full Disk Access cannot be requested programmatically — guide user to System Settings.
- **Recommendation:** Use sandbox for App Store distribution; non-sandbox for Developer-ID DMG.

---

## Appendix L: SwiftUI Layout Protocol

### Custom Split View
```swift
struct SplitLayout: Layout {
    var splitPosition: CGFloat // 0.0–1.0

    func sizeThatFits(proposal: ProposedViewSize,
                      subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        let splitX = bounds.minX + bounds.width * splitPosition
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.minY),
                          proposal: ProposedViewSize(width: splitX - bounds.minX,
                                                     height: bounds.height))
        subviews[1].place(at: CGPoint(x: splitX, y: bounds.minY),
                          proposal: ProposedViewSize(width: bounds.maxX - splitX,
                                                     height: bounds.height))
    }
}
```

### Key Rules
- Prefer `Layout` protocol over `GeometryReader` for container behavior.
- Use `cache` parameter for expensive layout calculations.
- `.layoutPriority(_:)` controls which views get truncated first.
- `ViewThatFits` renders the first child that fits the proposed space.
- Built-in containers (`LazyVStack`, `Grid`) are optimized for view recycling.

---

## Appendix M: Stripe Dashboard Design Principles

### What Makes It Feel Premium
1. **Strict tokenization:** All spacing uses documented tokens (small=8px, medium=16px, large=24px). No arbitrary pixels.
2. **Calm density:** Light `keyline: neutral` borders. Low-contrast background shifts. No heavy shadows.
3. **Performance as design:** Light, modular interaction models (`FocusView`, `ContextView`).
4. **Semantic meaning:** Every color conveys meaning (`critical` = error, `success` = payment).

### Table Design
- Neutral keyline borders. Subtle hover/selection tints.
- Tight vertical spacing via `DataTable` component.

### Form Design
- Helper text integrated beneath fields.\- Validation uses semantic color tokens + icons.
- `FormFieldGroup` enforces vertical consistency.

### Loading States
- Skeleton screens matching final layout structure.
- `Spinner` for transient operations.
- Content feels near-instant by masking latency.

---

## Appendix N: Obsidian Knowledge Graph Design

### Graph View
- **Nodes:** Notes, sized by inbound link count.
- **Edges:** Internal links between notes.
- **Filters:** Tags, attachments, orphans. Color-coded groups via search queries.
- **Physics:** Center/repel/link force sliders.
- **Local graph:** Notes within N degrees of separation from active note.

### Bidirectional Links
- `[[Note Name]]` wikilinks. Auto-update on file rename.
- **Backlinks panel:** Linked mentions + unlinked mentions (raw title occurrences).

### Search
- Full-text, `tag:#name`, `link:NoteName`, `path:folder`, boolean `OR`, `-exclude`.

### Editor Modes
- **Live Preview:** Renders markdown inline, switches to raw syntax on cursor entry.
- **Source Mode:** Raw markdown visible at all times.

---

---

## Appendix O: WKWebView Thumbnail Snapshots

### Recommended API: `takeSnapshot`

```swift
webView.takeSnapshot(with: WKSnapshotConfiguration()) { image, error in
    // image: NSImage? — the rendered snapshot
}
```

### Key Facts
- `CALayer.render(in:)` does NOT work for WKWebView — content is in a separate process.
- `takeSnapshot` handles cross-process IPC to rasterize web content.
- Do NOT snapshot all tabs at launch — batch and stagger.
- Off-screen tabs CAN be snapshotted if the WKWebView is initialized and loaded.

### Disk Caching
- Use `CGImageSource` for 30x faster resizing than `NSImage`.
- Store as compressed JPEG/WebP at exact grid cell size (e.g., 200×200).
- Use `NSCache` for in-memory thumbnails with strict cost limit.
- Generate at 2× backing scale for Retina sharpness.

### Update Strategy
- Snapshot on `didFinish` navigation (after page load).
- Snapshot when user enters tab overview (on-demand).
- Limit to once per few minutes per tab.
- Track scroll offset for significant change detection.

### Animation: Tab → Thumbnail
- `matchedGeometryEffect` for morphing between live WKWebView and thumbnail grid position.
- Snapshot acts as "view representation" during transition.

---

## Appendix P: matchedGeometryEffect Deep Dive

### How It Works
- Links layout identity of two views within a shared `@Namespace`.
- SwiftUI tracks geometric bounds of source view, interpolates consumer view's position/size.
- Conceptually: automatic declarative version of manual offset/frame/scale.

### Common Pitfalls
- **Namespace scope:** Must be accessible to all participating views.
- **Identity conflicts:** Multiple `isSource: true` for same ID = broken animation.
- **Modifier order:** Apply BEFORE `.frame`/`.padding`/`.offset`, AFTER view-specific modifiers.
- **Hierarchy changes:** Most effective in `if/else` blocks. Missing views → (0,0) position.

### Best Practices
- Tab switching: Background pill follows active tab via shared ID.
- Sidebar expand/collapse: Same ID, toggled in `if/else`.
- Use `withAnimation` (not `.animation()`) to avoid fighting.
- Limit to specific "hero" elements — not every list item.

### When NOT to Use
- Complex auto-reordering lists (use built-in list animations).
- Deep navigation (use `NavigationStack`).
- Data-driven layouts (use `Animatable` + custom `VectorArithmetic`).

---

## Appendix Q: PhaseAnimator & KeyframeAnimator

### PhaseAnimator (Multi-State Cycling)

```swift
// Shimmer effect
LinearGradient(colors: [.gray.opacity(0.3), .white, .gray.opacity(0.3)],
               startPoint: .leading, endPoint: .trailing)
    .phaseAnimator([0.0, 1.0], repeatForever: true) { content, phase in
        content.offset(x: phase == 0 ? -100 : 100)
    } animation: { _ in .linear(duration: 1.5) }

// Breathing pulse (Swarm icon)
Image(systemName: "ant.fill")
    .phaseAnimator([true, false], repeatForever: true) { content, phase in
        content.scaleEffect(phase ? 1.2 : 1.0)
    } animation: { _ in .snappy(duration: 1.0) }
```

### KeyframeAnimator (Frame-Level Control)

```swift
// Tab open animation with multiple stages
RoundedRectangle(cornerRadius: 20)
    .keyframeAnimator(initialValue: 0.0, trigger: isOpen) { content, value in
        content.scaleEffect(1 + value * 0.5).opacity(1 - value)
    } keyframes: { _ in
        KeyframeTrack(\.self) {
            CubicKeyframe(0.5, duration: 0.3)
            SpringKeyframe(0, spring: .bouncy)
        }
    }
```

### Summary
| Feature | Best For | Control Level |
|---|---|---|
| `withAnimation` | Simple on/off toggles | Low |
| `PhaseAnimator` | Repeating loops, multi-state switches | Medium |
| `KeyframeAnimator` | Complex multi-property choreography | High |

---

## Appendix R: Scroll Performance Optimization

### Critical Rules
1. **Always use `LazyVStack`/`LazyHStack`** — never eager-load entire lists.
2. **`.drawingGroup()`** — flattens complex views into single Metal-rendered bitmap. Use on containers with complex shapes/gradients. Don't apply prematurely.
3. **Minimize body evaluations:** Break views into smaller children. Use `EquatableView`. Use `Self._printChanges()` for debugging.
4. **`@StateObject` for owned objects, `@ObservedObject` for passed objects.** Creating objects in body = re-instantiation on every render.
5. **`.task` over `.onAppear`** — auto-cancels on disappear.
6. **Don't embed WKWebView in ScrollView** — gesture conflicts. Use WKWebView's native scrolling.
7. **Profile with Instruments:** SwiftUI template, Animation Hitches instrument, Time Profiler.

### Common Jank Causes
- Main thread disk I/O or networking in body.
- Over-invalidation of `@Published` properties.
- Eager loading instead of lazy containers.
- Overly complex view hierarchies in list rows.

---

## Appendix S: UNUserNotificationCenter for Browser

### Permission Strategy
```swift
// Use .provisional — non-intrusive, shows in Notification Center silently
center.requestAuthorization(options: [.alert, .badge, .sound, .provisional])
```

### Download Complete Notification
```swift
let content = UNMutableNotificationContent()
content.title = "Download Complete"
content.subtitle = fileName
content.sound = .default
categoryIdentifier = "DOWNLOAD"
threadIdentifier = "ACTIVE_DOWNLOADS" // Groups notifications
let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
```

### Action Buttons
```swift
let openAction = UNNotificationAction(identifier: "OPEN", title: "Open")
let category = UNNotificationCategory(identifier: "DOWNLOAD",
    actions: [openAction], intentIdentifiers: [])
UNUserNotificationCenter.current().setNotificationCategories([category])
```

### Key Facts
- Request permission on first relevant action, NOT on launch.
- Use `threadIdentifier` for grouping.
- Use WidgetKit (not notification updates) for download progress.
- Graceful denial: guide user to System Settings.

---

## Appendix T: Transferable Protocol for Drag & Drop

### Custom Transfer Type
```swift
struct TabItem: Codable, Transferable, Identifiable {
    let id: UUID
    var title: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}
```

### Usage
```swift
// Drag source
Text(tab.title).draggable(tab) { Text(tab.title) }

// Drop destination
.dropDestination(for: TabItem.self) { items, location in
    guard let moved = items.first else { return false }
    // Reorder logic
    return true
}
```

### Key Facts
- SwiftUI manages ESC cancellation and outside-drop automatically.
- Use `SigningGroup` for multiple transfer representations (custom + URL + text).
- Cross-app drag works via standardized types (`.url`, `.plainText`).
- Custom drag preview via `.draggable(value) { preview }` closure.

---

## Appendix U: NSVisualEffectView Materials

### Material Types
| Material | Usage |
|---|---|
| `.sidebar` | Navigation sidebars |
| `.headerView` | Table headers, footers |
| `.menu` | Dropdown/context menus |
| `.popover` | Popover backgrounds |
| `.hudWindow` | HUD overlays |
| `.contentBackground` | Main content area |

### Blending Modes
- `.behindWindow` (default): Blurs content behind window (desktop, other apps).
- `.withinWindow`: Blurs content within same window (custom overlays).

### SwiftUI Integration
```swift
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
```

### Key Facts
- SwiftUI's `.ultraThinMaterial` uses `NSVisualEffectView` under the hood.
- macOS 26 Liquid Glass replaces most `NSVisualEffectView` use cases.
- Set `state = .inactive` when window loses focus to save battery.
- Reduce Transparency → automatic fallback to solid colors.

---

## Appendix V: Accessible Custom Controls

### Essential Modifiers
```swift
.accessibilityLabel("Tab title")
.accessibilityHint("Selects this tab")
.accessibilityValue("50%")
.accessibilityAddTraits(.isButton)
.accessibilityAddTraits(.isSelected)
```

### Custom Tab Bar
- Each tab: `.accessibilityAddTraits(.isButton)` + `.isSelected` for active.
- Container: `.accessibilityElement(children: .contain)` for logical traversal.

### Accessibility Actions
```swift
.accessibilityAction(.magicTap) { /* primary action */ }
.accessibilityAction(.escape) { /* dismiss */ }
.accessibilityAdjustableAction { direction in /* slider-like */ }
```

### Dynamic Announcements
```swift
AccessibilityNotification.Announcement("File saved").post()
```

### Focus Management
```swift
@AccessibilityFocusState private var isFieldFocused: Bool
// .accessibilityFocused($isFieldFocused)
// Set isFieldFocused = true to programmatically move VoiceOver cursor
```

### Rotor Support
```swift
.accessibilityRotor("My Category", entries: items) { item in
    AccessibilityRotorEntry(item.title, id: item.id)
}
```

### Key Rules
- Always provide alternative to drag-and-drop (context menu or button).
- Test with Accessibility Inspector: Xcode > Open Developer Tool > Accessibility Inspector.
- Use `@AccessibilityFocusState` (not `@FocusState`) for VoiceOver focus.

---

*This document is a living specification. Update it as decisions are made and implementations land. Every change to the UI should be reflected here first, then implemented in code.*
