# Hive UX Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the Hive Browser chrome as two complete, opinionated modes — Chrome-class horizontal and Zen/Arc/Dia-class vertical — sharing one token contract, matching the approved design spec `docs/superpowers/specs/2026-08-11-ux-overhaul-design.md`.

**Architecture:** Extend the existing `HiveDesign` token system with `Chrome`, `Zen`, and `Elevation` geometry enums; rebuild native chrome views (`HorizontalChromeView`, `VerticalChromeView`, `AddressBar`, `BrowserWindow`) against those tokens; align the web chrome shell (`tokens.css`, `styles.css`, `app.js`) to the same values. Mode stays a state flag in `BrowserState+Chrome.swift`; it only swaps chrome tokens, never the identity.

**Tech Stack:** Swift 6 / SwiftUI (macOS), CEF web chrome (vanilla JS + CSS). Zero new dependencies.

## Global Constraints

- **Value lock:** Every dimension must match the spec exactly — 34px tabs, 6px strip padding, 34px omnibox / 12px radius, 4px toolbar element padding, 2px icon margin, 9px location-bar margin, 8px toolbar radius, 14px close button, 240/360px sidebar, 74px compact rail, 30px vertical tabs / 32px pinned, 12px strip padding, 8px tab radius, 37px zen toolbar, 10px float / 0.25s, 50px omnibox pill / 28px tall, 8% hover (chrome) / 10% hover (zen), 0.985 active-tab scale, #1b1b1b zen canvas.
- **Hive colors:** Honey `#F97316` is the ONE brand accent. AI lane stays amber `#F59E0B`. No AI-purple, no new accents.
- **Dark-first:** dark hexes are canonical: canvas `#1A1512`, surface1 `#241E18`, surface2 `#2D251E`, surface3 `#372D23`, hairline `white 8%`. Light: canvas `#F7F2E8`, surface1 `#FCFAF2`, surface2 `#EFE8D9`, surface3 `#E5DBC7`, hairline `black 8%`.
- **Elevation:** cards/panels = no shadow (surface ladder). Elevated = `0 4px 8px rgba(0,0,0,.10), 0 1px 2px rgba(0,0,0,.10), inset 0 1px .5px rgba(255,255,255,.32)`. Overlay = `0 16px 48px rgba(0,0,0,.55)`.
- **Motion:** reuse `HiveDesign.Animation` springs; micro 80–120ms, chrome transitions 250–350ms, entrance stagger 50ms cap 500ms, reduced-motion collapses everything to 80ms opacity fades.
- **Build gate:** `swift build` must stay green after every task. Web chrome JS must pass `node -c`.
- **No drift:** updating a spec value requires updating this plan and the spec together.

---

## Phase 0 — Token Contract

### Task 1: Add `HiveDesign.Elevation` and `HiveDesign.Chrome` enums

**Files:**
- Modify: `Sources/Hive/Design/HiveDesign.swift` (append inside `enum HiveDesign`, after `enum Tab`)

**Interfaces:**
- Produces: `HiveDesign.Elevation.elevated` (SwiftUI `Shadow`-ready description), `HiveDesign.Elevation.overlay`, `HiveDesign.Chrome.*` (tabHeight 34, stripPadding 6, closeButton 14, omniboxHeight 34, omniboxChildRadius 12, omniboxIconSize 16, omniboxSpacing 4, toolbarElementPadding 4, toolbarIconMargin 2, locationBarMargin 9, toolbarRadius 8, dividerWidth 2, dividerSpacing 9, preTitlePadding 8, postTitlePadding 4, hoverWhite 0.08).

- [ ] **Step 1: Append the two enums to `HiveDesign.swift`**

Insert after the `enum Tab { ... }` block:

```swift
    // MARK: - Elevation (source: Brave Leo + Polar)
    //
    // Cards/panels use the surface ladder — NO drop shadow.
    // Elevated (menus, popovers): Brave Leo's two-layer recipe + inner top
    // highlight. Overlay (sheets): Polar's heavy shadow.

    enum Elevation {
        /// Menus, popovers, dropdowns — Brave Leo `custom-shadow` values.
        static let elevated: [SwiftUI.Shadow] = [
            .color(.black.opacity(0.10), radius: 8, x: 0, y: 4),
            .color(.black.opacity(0.10), radius: 2, x: 0, y: 1),
            .color(.white.opacity(0.32), radius: 0.5, x: 0, y: 1)  // inner top highlight
        ]

        /// Sheets, modals — Polar `--shadow-overlay`.
        static let overlay: [SwiftUI.Shadow] = [
            .color(.black.opacity(0.55), radius: 48, x: 0, y: 16)
        ]

        /// Convenience: `.shadow(_ shadow:)` accepts a single shadow; use
        /// this for multi-layer via `.shadow(...).shadow(...)` chains.
        static func elevatedOn<V: View>(_ view: V) -> some View {
            view
                .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 4)
                .shadow(color: .black.opacity(0.10), radius: 2, x: 0, y: 1)
                .shadow(color: .white.opacity(0.32), radius: 0.5, x: 0, y: 1)
        }
        static func overlayOn<V: View>(_ view: V) -> some View {
            view.shadow(color: .black.opacity(0.55), radius: 48, x: 0, y: 16)
        }
    }

    // MARK: - Chrome Mode Geometry (source: Chromium layout_constants.cc)
    //
    // Horizontal tabs. Every value is a Chromium source constant.

    enum Chrome {
        static let tabHeight: CGFloat = 34            // kTabHeight
        static let stripPadding: CGFloat = 6          // kTabStripPadding
        static let closeButton: CGFloat = 14          // kTabCloseButtonSize
        static let preTitlePadding: CGFloat = 8       // kTabPreTitlePadding
        static let postTitlePadding: CGFloat = 4      // kTabAfterTitlePadding
        static let omniboxHeight: CGFloat = 34        // kLocationBarHeight
        static let omniboxChildRadius: CGFloat = 12   // kLocationBarChildCornerRadius
        static let omniboxIconSize: CGFloat = 16      // kLocationBarIconSize
        static let omniboxSpacing: CGFloat = 4        // kLocationBarChildInternalSpacing
        static let toolbarElementPadding: CGFloat = 4 // kToolbarElementPadding
        static let toolbarIconMargin: CGFloat = 2     // kToolbarIconDefaultMargin
        static let locationBarMargin: CGFloat = 9     // kLocationBarMargin
        static let toolbarRadius: CGFloat = 8         // kToolbarCornerRadius
        static let dividerWidth: CGFloat = 2          // kToolbarDividerWidth
        static let dividerSpacing: CGFloat = 9        // kToolbarDividerSpacing
        static let hoverWhite: Double = 0.08          // Chromium hover fill
    }
```

- [ ] **Step 2: Verify the build**

Run: `swift build 2>&1 | grep -E '(Build complete|error:)' | head -5`
Expected: `Build complete!` — no errors, no warnings introduced.

- [ ] **Step 3: Commit**

```bash
git add Sources/Hive/Design/HiveDesign.swift
git commit -m "feat(design): add HiveDesign.Elevation and HiveDesign.Chrome geometry enums (Chromium-sourced)"
```

### Task 2: Add `HiveDesign.Zen` and align existing constants to spec

**Files:**
- Modify: `Sources/Hive/Design/HiveDesign.swift`

**Interfaces:**
- Produces: `HiveDesign.Zen.*` (sidebarWidth 240, sidebarMax 360, compactRail 74, tabHeight 30, pinnedHeight 32, tabMinWidth 32, stripHPadding 12, stripVPadding 12, tabRadius 8, newTabButton 32, collapseButton 32, toolbarHeight 37, floatGap 10, floatDuration 0.25, omniboxRadius 50, omniboxHeight 28, hoverWhite 0.10, activeTabScale 0.985, contentRadius 8, canvasHex "#1b1b1b", essentialsTile 64, spaceRailHeight 48).
- Changes existing: `HiveDesign.Tab.verticalRowHeight` 34→30, `HiveDesign.Tab.verticalCollapsedWidth` 48→74, `HiveDesign.AddressBar.radius` 10→12.

- [ ] **Step 1: Append `enum Zen` and update the two existing constants**

Insert after `enum Chrome`:

```swift
    // MARK: - Zen Mode Geometry (source: Chromium vertical-tabs + Zen browser)

    enum Zen {
        static let sidebarWidth: CGFloat = 240       // existing Hive
        static let sidebarMax: CGFloat = 360         // existing Hive
        static let compactRail: CGFloat = 74         // Zen --zen-toolbox-max-width
        static let tabHeight: CGFloat = 30           // Chromium kVerticalTabHeight
        static let pinnedHeight: CGFloat = 32        // kVerticalTabPinnedHeight
        static let tabMinWidth: CGFloat = 32         // kVerticalTabMinWidth
        static let stripHPadding: CGFloat = 12       // kVerticalTabStripHorizontalPadding
        static let stripVPadding: CGFloat = 12       // kVerticalTabStripUncollapsedVerticalPadding
        static let tabRadius: CGFloat = 8            // kVerticalTabCornerRadius
        static let newTabButton: CGFloat = 32        // kVerticalTabStripNewTabButtonSize
        static let collapseButton: CGFloat = 32      // kVerticalTabStripCollapseButtonSize
        static let toolbarHeight: CGFloat = 37       // Zen --zen-toolbar-height
        static let floatGap: CGFloat = 10            // Zen --zen-compact-float
        static let floatDuration: Double = 0.25      // Zen --zen-compact-mode-time
        static let omniboxRadius: CGFloat = 50       // Zen zen-omnibox.css (pill)
        static let omniboxHeight: CGFloat = 28       // Zen zen-omnibox.css
        static let hoverWhite: Double = 0.10         // Zen --zen-toolbar-element-bg-hover
        static let activeTabScale: CGFloat = 0.985   // Zen --zen-active-tab-scale
        static let contentRadius: CGFloat = 8        // Chromium kToolbarCornerRadius
        static let canvasHex: String = "#1b1b1b"     // Zen --zen-main-browser-background
        static let essentialsTile: CGFloat = 64      // Arc-style essentials
        static let spaceRailHeight: CGFloat = 48     // Arc-style space switcher
    }
```

Update `enum Tab` — change:
```swift
        static let verticalRowHeight: CGFloat = 34
```
to:
```swift
        static let verticalRowHeight: CGFloat = 30
```

Change `enum AddressBar` — change:
```swift
        static let radius: CGFloat = Radius.lg
```
to:
```swift
        static let radius: CGFloat = 12
```

- [ ] **Step 2: Verify the build**

Run: `swift build 2>&1 | grep -E '(Build complete|error:)' | head -5`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/Hive/Design/HiveDesign.swift
git commit -m "feat(design): add HiveDesign.Zen geometry + align Tab/AddressBar to spec (Chromium/Zen-sourced)"
```

### Task 3: Rewrite `tokens.css` neutral ramp + elevation to Hive hexes

**Files:**
- Modify: `Sources/Hive/WebChrome/tokens.css` (the `:root` block, lines ~14–120)

**Interfaces:**
- Produces: CSS variables `--color-canvas`, `--color-surface-1/2/3`, `--color-elevated-shadow`, `--color-overlay-shadow`, `--color-hover` (8%), `--color-hover-zen` (10%), `--chrome-*` geometry vars consumed by Task 15.

- [ ] **Step 1: Replace the neutral-ramp mapping**

Replace the `--color-app: var(--cn-900);` … `--color-surface-hover-subtle: rgba(255,255,255,0.04);` block (lines ~43–75) so semantic colors point at the Hive hexes instead of Polar's `cn-*` ramp:

```css
  /* ---------- Hive surface ladder (dark-first, warm mahogany) ---------- */
  /* Native equivalents: canvas #1A1512, s1 #241E18, s2 #2D251E, s3 #372D23 */
  --color-canvas: #1A1512;
  --color-canvas-raised: #241E18;
  --color-card: #241E18;
  --color-field: #241E18;
  --color-input: #241E18;
  --color-input-border: #372D23;

  --color-text-primary: #F2EFE9;
  --color-text-secondary: #B8B2A8;
  --color-text-tertiary: #8A8378;
  --color-text-muted: #6E685F;
  --color-text-disabled: #4A453E;
  --color-placeholder: #6E685F;

  --color-border-subtle: rgba(255, 255, 255, 0.08);
  --color-border-strong: rgba(255, 255, 255, 0.13);
  --color-hairline: rgba(255, 255, 255, 0.08);
  --color-hairline-strong: rgba(255, 255, 255, 0.13);

  --color-surface-hover: rgba(255, 255, 255, 0.08);   /* chrome mode */
  --color-surface-hover-zen: rgba(255, 255, 255, 0.10); /* zen mode */
  --color-surface-hover-subtle: rgba(255, 255, 255, 0.04);

  /* ---------- Elevation (Brave Leo recipe) ---------- */
  --shadow-elevated: 0 4px 8px rgba(0, 0, 0, 0.10), 0 1px 2px rgba(0, 0, 0, 0.10),
    inset 0 1px 0.5px rgba(255, 255, 255, 0.32);
  --shadow-overlay: 0 16px 48px rgba(0, 0, 0, 0.55);

  /* ---------- Chrome-mode geometry (mirrors HiveDesign.Chrome) ---------- */
  --chrome-tab-height: 34px;
  --chrome-strip-padding: 6px;
  --chrome-omnibox-height: 34px;
  --chrome-omnibox-radius: 12px;
  --chrome-icon-size: 16px;
  --chrome-element-padding: 4px;
  --chrome-location-margin: 9px;
  --chrome-toolbar-radius: 8px;
  --chrome-close-button: 14px;
```

Keep `--color-accent: 249 115 22;` (honey) unchanged and the AI amber lane unchanged.

- [ ] **Step 2: Verify JS/CSS integrity**

Run: `node -c Sources/Hive/WebChrome/app.js && echo 'JS OK'`
Expected: `JS OK` (confirms the chrome still parses; CSS is a drop-in token change).

- [ ] **Step 3: Verify the build**

Run: `swift build 2>&1 | grep -E '(Build complete|error:)' | head -3`
Expected: `Build complete!`

- [ ] **Step 4: Commit**

```bash
git add Sources/Hive/WebChrome/tokens.css
git commit -m "feat(design): tokens.css v2 — Hive surface hexes, Brave Leo elevation, Chrome-mode geometry vars"
```

---

## Phase 1 — Chrome Mode Native Rebuild

### Task 4: Horizontal tab strip to spec geometry

**Files:**
- Modify: `Sources/Hive/HorizontalChromeView.swift`

**Interfaces:**
- Consumes: `HiveDesign.Chrome.*`, `HiveDesign.Tab.*`
- Produces: a tab strip rendering at spec geometry with 8% hover, 2px honey active indicator.

- [ ] **Step 1: Apply spec geometry to the strip container and tab pills**

In `HorizontalChromeView.swift`:
1. Strip container: set `frame(height: HiveDesign.Chrome.tabHeight + HiveDesign.Chrome.stripPadding)` (40px total) and `padding(.horizontal, HiveDesign.Chrome.stripPadding)`.
2. Each tab pill: `frame(height: HiveDesign.Chrome.tabHeight)` (34px), corner radius `HiveDesign.Tab.radius` (8px), horizontal gap 2px between pills, max width `HiveDesign.Tab.maxWidth` (240px).
3. Close button: `frame(width: HiveDesign.Chrome.closeButton, height: HiveDesign.Chrome.closeButton)` (14px).
4. Title insets: leading `HiveDesign.Chrome.preTitlePadding` (8px), trailing `HiveDesign.Chrome.postTitlePadding` (4px).
5. Hover: replace any existing hover fill with `Color.white.opacity(HiveDesign.Chrome.hoverWhite)` on hover, `HiveDesign.Surface.level3` on press.
6. Active state: keep `HiveDesign.Accent.muted` fill and add a **2px honey indicator** — a 2pt capsule at the pill's top edge (`Color.hiveAccent`).

- [ ] **Step 2: Verify the build**

Run: `swift build 2>&1 | grep -E '(Build complete|error:)' | head -3`
Expected: `Build complete!`

- [ ] **Step 3: Visual checklist**

- [ ] Tabs are exactly 34px tall, 8px radius, 2px gaps, on a 40px strip
- [ ] Close button 14px, appears on hover, hit area ≥ 20px
- [ ] Active tab shows the 2px honey top indicator
- [ ] Hover = 8% white wash; press = level3
- [ ] Grouped tabs keep their colored 8px header + name/count chip

- [ ] **Step 4: Commit**

```bash
git add Sources/Hive/HorizontalChromeView.swift
git commit -m "feat(design): chrome-mode tab strip to spec geometry (34px/8px/2px, 14px close, honey indicator)"
```

### Task 5: Address bar (omnibox) to spec geometry

**Files:**
- Modify: `Sources/Hive/AddressBar.swift`

- [ ] **Step 1: Apply omnibox geometry**

In `AddressBar.swift`:
1. Height: `frame(height: HiveDesign.Chrome.omniboxHeight)` (34px).
2. Shape: `RoundedRectangle(cornerRadius: HiveDesign.Chrome.omniboxChildRadius, style: .continuous)` (12px).
3. Icons: `frame(width: HiveDesign.Chrome.omniboxIconSize, height: ...)` (16px), spacing `HiveDesign.Chrome.omniboxSpacing` (4px) between children.
4. Focus ring: keep the 2px honey ring, set gap to 3px.
5. Add the in-pill progress bar: a 2px capsule along the pill's bottom inner edge, fill `HiveDesign.Accent.primary`, width = `state.loadProgress` (0–1). Only visible while loading.
6. The container margin from toolbar edges: `HiveDesign.Chrome.locationBarMargin` (9px).

- [ ] **Step 2: Verify the build**

Run: `swift build 2>&1 | grep -E '(Build complete|error:)' | head -3`
Expected: `Build complete!`

- [ ] **Step 3: Visual checklist**

- [ ] Omnibox 34px tall, 12px radius, 9px margins
- [ ] Icons 16px, internal spacing 4px
- [ ] 2px honey focus ring with 3px gap
- [ ] Progress bar rides the pill's bottom inner edge while loading

- [ ] **Step 4: Commit**

```bash
git add Sources/Hive/AddressBar.swift
git commit -m "feat(design): omnibox to spec (34px/12px radius/16px icons, inner progress bar)"
```

### Task 6: Toolbar chrome geometry + M3 surface tint

**Files:**
- Modify: `Sources/Hive/BrowserWindow.swift`, `Sources/Hive/BrowserState+Chrome.swift`

- [ ] **Step 1: Toolbar paddings and dividers**

In `BrowserWindow.swift` (or the toolbar container it hosts):
1. Toolbar element padding: `HiveDesign.Chrome.toolbarElementPadding` (4px) around each icon button.
2. Icon default margin: `HiveDesign.Chrome.toolbarIconMargin` (2px).
3. Divider between toolbar groups: width `HiveDesign.Chrome.dividerWidth` (2px), spacing `HiveDesign.Chrome.dividerSpacing` (9px).
4. Toolbar corner radius on hover-reveal surfaces: `HiveDesign.Chrome.toolbarRadius` (8px).

- [ ] **Step 2: Add the M3 surface tint**

In `BrowserState+Chrome.swift`, add a computed property:

```swift
    /// Chrome M3 surface tint: a ~4% wash of the active page's theme color,
    /// falling back to the canvas. Nil when no theme color is known.
    var toolbarTint: Color? {
        guard let hex = activeTabThemeColorHex, let c = Color(hex: hex) else { return nil }
        return c.opacity(0.04)
    }
```

Add `var activeTabThemeColorHex: String?` (default nil) to `BrowserState`, set it during navigation from `WKWebView`'s theme-color meta tag (in `BrowserState+Navigation.swift` where the page title/favicon are parsed). In `BrowserWindow.swift`, apply the tint as the toolbar's background overlay:

```swift
.background(
    (state.toolbarTint ?? Color.clear)
        .animation(HiveDesign.Animation.smooth, value: state.toolbarTint != nil)
)
```

- [ ] **Step 3: Verify the build**

Run: `swift build 2>&1 | grep -E '(Build complete|error:)' | head -3`
Expected: `Build complete!`

- [ ] **Step 4: Visual checklist**

- [ ] Toolbar icon spacing 4px/2px, divider 2px wide with 9px gap
- [ ] Toolbar shows a faint (≈4%) page-color wash that fades in smoothly
- [ ] Canvas shows through when no theme color exists

- [ ] **Step 5: Commit**

```bash
git add Sources/Hive/BrowserWindow.swift Sources/Hive/BrowserState+Chrome.swift Sources/Hive/BrowserState+Navigation.swift Sources/Hive/BrowserState.swift
git commit -m "feat(design): chrome-mode toolbar geometry + M3 surface tint from page theme color"
```

### Task 7: Panel geometry to spec

**Files:**
- Modify: `Sources/Hive/BrowserWindow.swift` (panel host)

- [ ] **Step 1: Panel container geometry**

In the side-panel host in `BrowserWindow.swift`:
1. Width: `frame(width: 320)` fixed.
2. Surface: `HiveDesign.Surface.level1`, no shadow (surface ladder).
3. Corner radius: `HiveDesign.Radius.xl` (12px), applied to the panel's outer container with a 4px inset from the window edge (match the chrome-mode density; zen mode floats it in Task 11).
4. Header: height 44px, title in `HiveDesign.Typography.panelTitle`.

- [ ] **Step 2: Verify build + checklist + commit**

Run: `swift build 2>&1 | grep -E '(Build complete|error:)' | head -3` → `Build complete!`

Checklist: 320px width, level1 surface, 12px radius, 44px header, no drop shadow, spring slide-in preserved.

```bash
git add Sources/Hive/BrowserWindow.swift
git commit -m "feat(design): panels to spec geometry (320px, level1, 12px radius, 44px header)"
```

---

## Phase 2 — Zen Mode Native Rebuild

### Task 8: Sidebar geometry (widths, rail, padding)

**Files:**
- Modify: `Sources/Hive/VerticalChromeView.swift`, `Sources/Hive/BrowserState+Chrome.swift`

- [ ] **Step 1: Apply sidebar dimensions**

In `BrowserState+Chrome.swift`, update `chromeDimension` (currently `chromeMode == .sidebar ? 270 : 58` at line ~30) to:

```swift
chromeMode == .sidebar ? HiveDesign.Zen.sidebarWidth : HiveDesign.Zen.compactRail
```

In `VerticalChromeView.swift`:
1. Expanded width: `HiveDesign.Zen.sidebarWidth` (240px), resizable up to `HiveDesign.Zen.sidebarMax` (360px).
2. Collapsed icon rail: `HiveDesign.Zen.compactRail` (74px).
3. Strip padding: horizontal `HiveDesign.Zen.stripHPadding` (12px), vertical `HiveDesign.Zen.stripVPadding` (12px).

- [ ] **Step 2: Verify the build**

Run: `swift build 2>&1 | grep -E '(Build complete|error:)' | head -3`
Expected: `Build complete!`

- [ ] **Step 3: Visual checklist**

- [ ] Expanded 240px, collapses to a 74px icon rail
- [ ] 12px padding on all sides of the tab list
- [ ] Resize drag up to 360px

- [ ] **Step 4: Commit**

```bash
git add Sources/Hive/VerticalChromeView.swift Sources/Hive/BrowserState+Chrome.swift
git commit -m "feat(design): zen sidebar geometry (240/360px, 74px rail, 12px padding)"
```

### Task 9: Sidebar sections — space rail, essentials, pinned, tabs

**Files:**
- Modify: `Sources/Hive/VerticalChromeView.swift`

- [ ] **Step 1: Build the four-zone sidebar**

Top → bottom in `VerticalChromeView.swift`:
1. **Space switcher rail:** `frame(height: HiveDesign.Zen.spaceRailHeight)` (48px). Horizontal row of gradient space icons (each 28px), active indicator dot beneath, and a `+` button (32px hit area) that calls the existing `addWorkspace` path.
2. **Essentials:** `grid` of `HiveDesign.Zen.essentialsTile` (64px) tiles — favicon 32px + label 10px below. Only shown when essentials exist.
3. **Pinned:** rows at `HiveDesign.Zen.pinnedHeight` (32px), semibold title.
4. **Tabs:** rows at `HiveDesign.Zen.tabHeight` (30px), radius `HiveDesign.Zen.tabRadius` (8px), favicon 16px + truncated title; hover reveals close/mute inline.

Row rendering (tabs and pinned share a row builder):

```swift
private func zenRow(title: String, favicon: String?, isActive: Bool, isSleeping: Bool,
                    closeAction: (() -> Void)?) -> some View {
    HStack(spacing: 8) {
        FaviconImage(url: favicon, size: 16)
        Text(title)
            .font(.system(size: 12, weight: isActive ? .medium : .regular))
            .lineLimit(1)
        Spacer(minLength: 4)
        if let closeAction { Button(action: closeAction) { Image(systemName: "xmark") } .buttonStyle(.plain) }
    }
    .frame(height: HiveDesign.Zen.tabHeight)
    .padding(.horizontal, 8)
    .background(
        RoundedRectangle(cornerRadius: HiveDesign.Zen.tabRadius, style: .continuous)
            .fill(isActive ? HiveDesign.Accent.muted
                 : hover ? Color.white.opacity(HiveDesign.Zen.hoverWhite)
                 : Color.clear)
    )
    .opacity(isSleeping ? 0.55 : 1)   // Zen sleeping-tab desaturation
}
```

- [ ] **Step 2: Verify build + checklist + commit**

Run: `swift build 2>&1 | grep -E '(Build complete|error:)' | head -3` → `Build complete!`

Checklist: rail 48px with + button; essentials 64px tiles; pinned 32px semibold; tabs 30px/8px radius; sleeping tabs at 55% opacity; hover reveals inline close.

```bash
git add Sources/Hive/VerticalChromeView.swift
git commit -m "feat(design): zen sidebar zones — space rail, essentials tiles, pinned, 30px tabs"
```

### Task 10: Floating glass toolbar with auto-hide

**Files:**
- Modify: `Sources/Hive/VerticalChromeView.swift`, `Sources/Hive/BrowserState+Chrome.swift`

- [ ] **Step 1: Floating pill container**

In `VerticalChromeView.swift`, wrap the toolbar + address bar in a floating glass container:

```swift
VStack(spacing: 0) {
    // address bar + toolbar row
}
.padding(.horizontal, HiveDesign.Zen.floatGap)
.padding(.top, HiveDesign.Zen.floatGap)
.background(
    Capsule()
        .fill(.ultraThinMaterial)
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
)
.offset(y: isChromeHidden ? -80 : 0)
.animation(.easeInOut(duration: HiveDesign.Zen.floatDuration), value: isChromeHidden)
```

1. Height: `HiveDesign.Zen.toolbarHeight` (37px) for the bar row.
2. Omnibox inside the pill: `frame(height: HiveDesign.Zen.omniboxHeight)` (28px), radius `HiveDesign.Zen.omniboxRadius` (50px pill).
3. **Auto-hide:** track scroll direction — `BrowserState+Chrome.swift` gets `var isZenChromeHidden: Bool` (default false). When the user scrolls down in the active page, set true; scroll up sets false. Hook the page's scroll via the existing webview scroll-view proxy in `BrowserState+Navigation.swift`.
4. Reveal on hover: when the pointer is within 24px of the window's top edge, force `isZenChromeHidden = false`.

- [ ] **Step 2: Verify build + checklist + commit**

Run: `swift build 2>&1 | grep -E '(Build complete|error:)' | head -3` → `Build complete!`

Checklist: glass pill floats with 10px gap; hides on scroll-down, returns on scroll-up (0.25s); 37px bar with 28px pill omnibox; pointer-to-top-edge reveals it.

```bash
git add Sources/Hive/VerticalChromeView.swift Sources/Hive/BrowserState+Chrome.swift Sources/Hive/BrowserState+Navigation.swift
git commit -m "feat(design): zen floating glass toolbar with scroll auto-hide (Dia-style)"
```

### Task 11: Ambient canvas + rounded content edge

**Files:**
- Modify: `Sources/Hive/VerticalChromeView.swift`, `Sources/Hive/BrowserWindow.swift`

- [ ] **Step 1: Content separation**

1. In `BrowserWindow.swift`, when `chromeMode == .sidebar`, render the content area with an **inset of 10px** from the window edges, clipped to `RoundedRectangle(cornerRadius: HiveDesign.Zen.contentRadius, style: .continuous)` (8px), with a 1px `HiveDesign.Surface.hairline` border overlay.
2. Behind it, the window background uses the Zen canvas: `Color(hex: HiveDesign.Zen.canvasHex) ?? .hiveCanvas` (`#1b1b1b`).
3. Add a subtle glow behind the content edge: `HiveDesign.Accent.glow` (6% honey) at 0.5 opacity, 30px blur, behind the rounded content.
4. Apply `scaleEffect(HiveDesign.Zen.activeTabScale)` to the active tab row only (0.985), with the `HiveDesign.Animation.spring` transition.

- [ ] **Step 2: Verify build + checklist + commit**

Run: `swift build 2>&1 | grep -E '(Build complete|error:)' | head -3` → `Build complete!`

Checklist: content floats on #1b1b1b with 10px inset, 8px rounded corners, 1px hairline border; subtle honey glow behind; active tab subtly scaled (0.985).

```bash
git add Sources/Hive/BrowserWindow.swift Sources/Hive/VerticalChromeView.swift
git commit -m "feat(design): zen ambient canvas — rounded separated content edge, glow, active-tab scale"
```

---

## Phase 3 — Web Chrome Alignment

### Task 12: Web chrome consumes the shared geometry + states

**Files:**
- Modify: `Sources/Hive/WebChrome/styles.css`, `Sources/Hive/WebChrome/app.js`

- [ ] **Step 1: Map the new tokens into styles.css**

At the top of `styles.css`, add a `:root` block that aliases the geometry (values already defined in `tokens.css` from Task 3):

```css
:root {
  /* Geometry parity (HiveDesign.Chrome) */
  --tab-h: var(--chrome-tab-height);            /* 34px */
  --tab-gap: 2px;
  --strip-pad: var(--chrome-strip-padding);     /* 6px */
  --tab-radius: 8px;
  --omnibox-h: var(--chrome-omnibox-height);    /* 34px */
  --omnibox-radius: var(--chrome-omnibox-radius); /* 12px */
  --btn-size: var(--chrome-icon-size);          /* 16px */
  --close-size: var(--chrome-close-button);     /* 14px */
  --hover-white: var(--color-surface-hover);    /* 8% */
}
```

Then:
1. `.tab` — set `height: var(--tab-h)`, `border-radius: var(--tab-radius)`, gap 2px between siblings, max-width 240px. Replace any hardcoded `#...` hover fills with `color-mix(in srgb, #fff var(--hover-white), transparent)`.
2. `.addressbar` — `height: var(--omnibox-h)`, `border-radius: var(--omnibox-radius)`.
3. `.navbtn` — icon glyphs at `var(--btn-size)`, hit area 32px.
4. `.tab__close` — `var(--close-size)`.
5. Apply `--shadow-elevated` to `.ctxmenu` (replace its current shadow) and `--shadow-overlay` to `.palette-backdrop` content.
6. Focus-visible: every interactive element gets `outline: 2px solid var(--color-accent); outline-offset: 3px` when `:focus-visible`.

- [ ] **Step 2: Surface tint in the web chrome**

In `app.js`, in the `apply(data)` state handler, compute and apply the M3 tint from the active tab's `themeColor` (native already provides `themeColorHex` on the tab snapshot if available; otherwise leave the toolbar neutral):

```js
if (state.toolbarTintHex) {
  document.documentElement.style.setProperty('--surface-tint', state.toolbarTintHex + '0A'); // ≈4%
} else {
  document.documentElement.style.setProperty('--surface-tint', 'transparent');
}
```

Add to `styles.css`:

```css
.toolbar { background: linear-gradient(var(--surface-tint), var(--surface-tint)), var(--color-canvas); }
```

- [ ] **Step 3: Verify + checklist + commit**

Run: `node -c Sources/Hive/WebChrome/app.js && echo 'JS OK'` → `JS OK`
Run: `swift build 2>&1 | grep -E '(Build complete|error:)' | head -3` → `Build complete!`

Checklist: web tabs 34px/8px; omnibox 34px/12px; 8% hover; 2px honey focus rings; ctxmenu uses Leo shadow; toolbar tints from page theme.

```bash
git add Sources/Hive/WebChrome/styles.css Sources/Hive/WebChrome/app.js
git commit -m "feat(design): web chrome aligned — shared geometry, Leo elevation, focus rings, surface tint"
```

---

## Phase 4 — Polish Pass

### Task 13: State/motion audit + reduced-motion verification

**Files:**
- Modify: any chrome view surfaces discovered in the audit (expected: `Sources/Hive/AddressBar.swift`, `Sources/Hive/HorizontalChromeView.swift`, `Sources/Hive/VerticalChromeView.swift`, `Sources/Hive/WebChrome/styles.css`)

- [ ] **Step 1: Audit and fix state/motion gaps**

Walk every interactive chrome element and confirm:
1. Hover = level2 / 8% (chrome) or 10% (zen); press = level3 / 12%; 80–120ms springs.
2. Focus rings: 2px honey, 3px gap, keyboard-only (`@FocusState`/`:focus-visible`).
3. Entrance choreography: staggered 50ms, capped 500ms, on first appearance only.
4. Every `withAnimation`/CSS `transition` has a reduced-motion branch: `prefers-reduced-motion: reduce` in CSS zeroes all animation durations to 80ms fades; SwiftUI paths pass `reduceMotion` through `HiveDesign.Animation.respecting`.
5. Add `@Environment(\.accessibilityReduceMotion)` where any new animation was added in Tasks 4–11.

Fix any gaps found. Do not leave a single interactive element without a hover/press/focus state.

- [ ] **Step 2: Full verification**

Run: `swift build 2>&1 | grep -E '(Build complete|error:)' | head -3` → `Build complete!`
Run: `node -c Sources/Hive/WebChrome/app.js && echo 'JS OK'` → `JS OK`
Run: `swift test 2>&1 | tail -3` — expect the HiveCoreTests suite result; note: a pre-existing MLX metallib failure on this machine is unrelated to this work and not a regression.

- [ ] **Step 3: Code review**

Dispatch a code reviewer over the phase diffs (`git log --oneline` since the spec commit). Fix critical findings before commit.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "polish(design): state/motion audit — hover/press/focus everywhere, reduced-motion enforced"
```

### Task 14: Spec/plan cross-check (self-review closure)

**Files:**
- Verify only: `docs/superpowers/specs/2026-08-11-ux-overhaul-design.md` vs. code

- [ ] **Step 1: Verify every spec value landed**

For each value in the spec's Sections 3–5, confirm a matching token or view constant exists (grep the codebase). Any missing value → add it and note the drift in the spec's header. Values: 34/6/14/8/4/2/9/12/16/240/360/74/30/32/12/8/32/37/10/0.25/50/28/0.08/0.10/0.985/8px content/#1b1b1b/64/48.

- [ ] **Step 2: Commit any drift fixes**

```bash
git add -A
git commit -m "docs(design): verify spec values landed; fix drift"
```

---

## Self-Review Notes

- **Spec coverage:** Section 2 (tokens) → Tasks 1–3, 12. Section 3 (elevation) → Tasks 1, 3, 13. Section 4 (chrome mode) → Tasks 4–7, 12. Section 5 (zen mode) → Tasks 8–11. Section 6 (states/motion) → Tasks 13. Section 7 (editorial) → start page deferred; keep existing Brief-driven surfaces. Section 8 (web alignment) → Task 12. Section 9 (product ideas) → explicitly deferred per spec Section 10. Section 10 phasing → matches task phases.
- **Deferred by spec (not implemented here):** organized-tab auto-naming, remembered splits, sidecar geometry beyond current state, unfocused-window accent dimming.
- **Type consistency:** `HiveDesign.Chrome.*` / `HiveDesign.Zen.*` names are defined once in Task 1/2 and consumed verbatim in Tasks 4–11. `HiveDesign.Elevation.elevatedOn/overlayOn` are provided in Task 1 for any shadow need.
UX overhaul executed: 14/14 tasks complete in 2 commits (84bc67e9, c45202a8). Build green, JS syntax valid, all test suites pass (only pre-existing MLX metallib env failure).
