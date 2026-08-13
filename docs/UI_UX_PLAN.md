# Hive UI/UX Repair Plan

> Written after the full-repo audit (2026-08-13). Grounded in code evidence, not vibes.
> One goal: make Hive read as a real, finished browser — not a first-year project.

## The one-line diagnosis

The product is ~85% real code, but the *visible* layer is where the rot lives.
19 of the web chrome's buttons call bridge methods that Swift never registered,
so "Find in page", "Save password", "Translate page", "View source", "Download",
and the permission prompts all **silently do nothing** when clicked. A browser
whose buttons don't work cannot look good — fixing the dead surface is the first
visual fix, not a separate engineering task.

## Phase 0 — Make every button work (blocking, before any styling)

Wire the 19 unregistered bridge methods to their native implementations. The
contract test `WebChromeBridgeContractTests.everyBridgeCallFromWebChromeIsRegistered`
must go green — it is the regression guard that proves no button is silently dead.

| JS call | Native target | Status |
|---|---|---|
| `hive.addBookmark` | `addBookmark(Bookmark)` | exists |
| `hive.autofillCredentials` | `fillAutofill` / new autofill path | wire |
| `hive.clearReadingList` | new: `readingList.removeAll()` | new |
| `hive.clearSiteData` | new: cookies + cache for host | new |
| `hive.dismissRestore` | `dismissSessionRepairNotice()` | exists |
| `hive.downloadURL` | new: `saveImageAs`-style fetch+save | new |
| `hive.findInPage` / `findNext` / `findInPageDone` | `findInPage` / `findNext/PrevInPage` / `clearFindHighlights` | exists |
| `hive.neverSavePassword` | `neverSavePasswordForHost` | exists |
| `hive.newWindowWithURL` | new window + navigate | new |
| `hive.openDevTools` | `CefBrowser.showDevTools()` | exists |
| `hive.removeFromReadingList` | `removeFromReadingList(id:)` | exists |
| `hive.respondPermission` | `resolvePermissionPrompt(allow:)` | exists |
| `hive.savePage` | new: HTML fetch + save panel | new |
| `hive.savePassword` | `savePassword(username:password:site:)` | exists |
| `hive.setSitePermission` | `setSitePermission(_:forHost:kind:isPrivate:)` | exists |
| `hive.translatePage` | `translateCurrentPage(targetLanguage:)` | exists |
| `hive.viewSource` | navigate to `view-source:` URL | new |

## Phase 1 — One reference, one mode

Pin **Chrome M3** as the single visual reference for the horizontal chrome
(Chrome-mode is the default and the first thing anyone sees). Zen/Arc vertical
mode is deferred — it is already implemented and does not block launch.

Reference facts (Chrome M3, dark, macOS):
- Tab strip: 34px pill tabs, inactive tabs have no fill, active tab is a
  raised surface, hover shows a faint fill.
- Omnibox: centered pill, ~40px tall, focused state gets a subtle border ring.
- Toolbar: 8px gaps, 28px icon buttons with 16px glyphs, quiet hover states.
- Type: SF Pro, 13px UI base, 12px secondary, tabular numerals for counts.

## Phase 2 — A real type scale + spacing rhythm (the thing the last plan missed)

The old "UX overhaul" copied pixel constants but never built a *system*. Fix:
- One 4px spacing base (4/8/12/16/24/32), no arbitrary values.
- One type scale (12/13/14/16/20/28/40), tabular numerals where numbers change.
- One surface ladder (canvas / surface-1 / surface-2 / surface-3 / hover).
- One accent (honey `#F97316` on warm canvas `#1A1512`), no rainbow.

These already exist as CSS variables in `tokens.css` v2. The work is enforcing
them across `WebChrome/styles.css` and the landing `web/styles.css` — not
inventing new ones.

## Phase 3 — Craft on the start page (the first impression)

The `hive://start` page is the new-tab surface. Against Chrome M3:
- Search box centered, large, quiet — no competing hero.
- Top sites: 8-icon grid, monochrome favicon tiles, hover lift, no emoji.
- Recently visited + spaces: flat rows, section labels in 12px caps.
- Remove the remaining ambient-particle/canvas slop (the `<canvas>` element is
  already deleted; the `HiveAmbientParticles` SwiftUI view + `.stage-particles`
  CSS are the leftovers).

## Phase 4 — States, not just static layout

Every interactive element needs hover, press, focus, and disabled states. The
audit found the design system has the tokens but the chrome never applied them
consistently. Cover: tab hover/press, omnibox focus, button hover/press,
dropdown open/close, empty states (no downloads, no history, no top sites).

## Phase 5 — Delete the slop that remains

- `Sources/Hive/WebChrome/app.js`: the `HivePhysics` particle/confetti engine
  is now inert (its canvas is gone) — remove the dead code.
- `Sources/Hive/WebChrome/styles.css`: `.stage-particles`, `.confetti-overlay`,
  `.counter-animate` blocks.
- The 2 GB of competitor package contents under `RECOVERED:USABLE:COPYABLE
  CONTENTS/` must leave the repo (legal/diligence, not visual — but it is the
  single heaviest non-visual liability found).

## Acceptance bar (how we know it is done)

1. `swift test` is green, including the bridge-contract test.
2. A fresh window looks like Chrome M3, not a themable tech demo — at a glance,
   an observer can name the reference.
3. Clicking Find-in-page, Save password, Translate, View source, Download, and
   a permission prompt each produces a visible result.
4. No floating particles, no confetti, no fake counters, no emoji-icon grids.

## Order of execution (this pass)

1. Bridge fix (Phase 0) — unblocks the contract test.
2. Start-page + chrome CSS pass (Phases 2–3) against Chrome M3.
3. States pass (Phase 4).
4. Slop deletion (Phase 5).
5. Full `swift test` + `node --check` on edited JS.
