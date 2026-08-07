# Hive Recovery & Ship Plan

One-shot autonomous recovery: repair, verify, document, and ship the Hive
browser from the state found in the worktree (docs-only git history; product
source never committed; two live defects).

**Branch:** `mission/recovery-and-ship` — every claim backed by evidence
(`.hive/mission/baseline/`, `.hive/mission/evidence/`, `docs/DECISIONS.md`).

## Status

| Task | Scope | Status | Evidence |
| --- | --- | --- | --- |
| T01 | Baseline: build, tests, smoke | ✅ | `.hive/mission/baseline/*.log` |
| T02 | Ledger + docs (this file, ARCHITECTURE, DECISIONS) | ✅ | `docs/` |
| T03 | Live fixes: duplicate start tab, `hive://` scheme | ✅ | CDP flow; commit `f19c0c5` |
| T04 | Adversarial QA (corrupt session, crash recovery) | ✅ headless | relaunch tests; UI-level ops deferred — needs human/visual pass |
| T05 | UI review (screenshots + a11y) | ⏳ blocked on visual | `.hive/mission/evidence/window-t05.png` (model has no image input) |
| T06 | Security: entitlements, debug port, secrets | ✅ | commit `d39da2b` |
| T07 | Release validation: build, preflight, smoke | ⏳ next | — |
| T08 | Final docs + coherent history | ⏳ | — |

## Found defects (fixed)

- **Bug A — duplicate start tab on fresh launch.** `setupDefaults()` called
  `newTab()` after `createDefaultProfiles()` had already created one. Fixed by
  removing the duplicate calls.
- **Bug B — `hive://` and `cefswift://` failed with `ERR_UNKNOWN_URL_SCHEME`.**
  Tabs use per-workspace CefProfile request contexts; CEF scheme handler
  factories are per-context and not inherited. Fixed by vendoring CefSwift
  (pinned, MIT) and replaying registered handlers onto each new context.

## Remaining work

1. **T07** — full release validation: `scripts/build-hivechromium-app.sh
   --allow-adhoc`, preflight, entitlement checks, smoke, `swift test`.
2. **T05** — human visual pass on `window-t05.png` (and any UI fixes).
3. **T04 remainder** — UI-level adversarial ops (rapid tab create/close,
   reorder, keyboard) via interactive browser automation or manual.
4. **T08** — `FINAL_VALIDATION.md`, `THIRD_PARTY_NOTICES.md` (CefSwift MIT,
   CEF BSD-ish, mlx-swift Apache-2.0), coherent commit history, push.

## Out of scope (noted)

- `hive-train/` (18 GB ML weights/pipeline) — gitignored, never versioned.
- Legacy WKWebView `Hive` target — kept buildable only.
- Upstream CefSwift `main` (CEF 151) — no fix upstream; CEF 148 pinned.
