# CHROME-SPEC v2 — the chrome agents implement against (W1 gate)

Written before any chrome code. Zen-bar checklist at the bottom is scored W2 and W4;
<7/8 blocks external exposure regardless of E2E green.

## Window region diagram

- One window. Hidden titlebar, fullSizeContentView; traffic lights float over the
  sidebar header (inset 12,10). No double titlebar ever.
- LEFT: sidebar 260px expanded / 34px collapsed rail (Cmd+Shift+B, persisted).
  Compact hover-overlay DEFERRED post-test. Sidebar ships pinned + collapse-to-rail.
- Content area top strip: toolbar, 44px tall - [back][fwd][reload] ( omnibox ) [capture][ask].
- Ask panel: DOCKED right, 380px, slides in 200ms (W1 decision: docked, not overlay).
- Omnibox centered, max-width 640px.

## Tokens (dark-first)

Type pairing: Manrope (UI) + JetBrains Mono (citations/spans). v1 MASTER.md tokens
are reference-only; no teal/orange/Inter carries forward.

--bg0:#141312 --bg1:#1B1918 --bg2:#232120 --bg3:#2B2827
--text:#F4F1EE --text-2:#C9C4BD --text-3:#8F8A82
--accent:#E8A33D --accent-press:#C98A2E --danger:#E5645A --ok:#6FBF8E
--hairline:rgba(255,255,255,.08)
--r-ctl:6px --r-card:8px
--dur-fast:120ms --dur-slide:200ms --ease:cubic-bezier(.2,0,0,1)

Light theme ships post-test; structure tokens for it now.

## Motion table

Rail toggle width 200ms ease / Ask panel translateX 200ms ease / Tab active bg 120ms /
Hover bg 120ms / Spinner rotate 800ms linear. Nothing bounces, no overshoot.
prefers-reduced-motion => all durations 1ms.

## Component state tables (loading/empty/error/success/partial - every empty state warm + primary action)

- Omnibox suggestions: empty query -> 6 recents; no matches -> "No matches - Enter to search"; rows kind-icon+title+host.
- Capture button: idle [Capture] -> running spinner "Capturing..." disabled -> success check flash -> idle; failed -> toast "Couldn't extract this page" + [Save visible text] [Dismiss].
- Ask panel: empty -> warm first-run ("Ask anything about what you've captured." + primary [Capture a page]); streaming -> live token append + Stop; done -> answer with citation chips [1][2]; refused two flavors (empty-corpus vs no-support); dropped claims render greyed footnote "removed an unsupported claim"; error -> "Generation failed - Try again".
- New-tab page (hive://start): greeting, recents grid, recently-captured list; first run shows onboarding card (capture -> ask, one CTA) + model note when weights absent ("Answers run on this Mac; ~2.3GB download on first ask"). No fake counters.

## Tab anatomy (vertical)

34px row height; >=24px close hit area; favicon 16px; title ellipsis-truncated;
active = --bg3 + 2px accent left inset; hover = --bg2. Pinned = favicon-only 48px
section above unpinned. Overflow: scroll + fade mask + auto-scroll-to-active;
arrow-key navigation moves selection, Enter activates.

## Keyboard map (focus visible everywhere, ring 2px accent offset 1px, hit targets >=28px, contrast >=4.5:1)

Cmd+T new / Cmd+W close / Cmd+L omnibox / Cmd+R reload / Cmd+[ back Cmd+] forward /
Cmd+D bookmark / Cmd+E capture / Cmd+K ask toggle / Cmd+Shift+B rail toggle /
Ctrl+Tab cycle tabs / Cmd+1..9 nth tab / Esc closes panel+suggestions.

## Breakpoints

Window <900px wide => sidebar auto-collapses to rail (separate persisted state from manual choice). <600px ask panel opens over content with scrim.

## Citation click-through (proof-of-memory moment)

Citation chip click opens Reader View (app page on pageToken) rendering that capture's stored text with the cited span highlighted and scrolled into view. Reader View header shows source host, captured date, version.

## Zen-bar scored checklist (W2 + W4, floor machine, <7/8 blocks external exposure)

1. Sidebar slide <=200ms named easing, 60fps no jank
2. 34px rail toggle persists across restart
3. Traffic lights integrated, no double titlebar
4. Tab anatomy complete (favicon, truncated title, >=24px close, unmistakable active)
5. Omnibox focus ring, inline progress, Cmd+L
6. Blind side-by-side vs Zen at three matched states - indistinguishable or favorable
7. Keyboard completeness with focus visible everywhere
8. Motion restraint - no bounce/overshoot, reduced-motion honored
