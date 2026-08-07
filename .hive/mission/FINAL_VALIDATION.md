# Hive Recovery Mission — Final Validation

**Branch:** `mission/recovery-and-ship`
**Date:** 2026-08-07

## Summary

The Hive browser was recovered from a repo whose history contained only docs.
The full product source (Swift, Rust, vendored CefSwift, tests, scripts) is now
committed, two live defects were found via CDP-driven verification and fixed
with root-cause patches, and the release pipeline validates clean.

## Verified evidence (reproducible)

| Check | Command | Result |
| --- | --- | --- |
| Compile | `swift build --product HiveChromium` | 0 errors |
| Unit tests | `swift test` | 983 tests / 130 suites pass |
| Release bundle | `scripts/build-hivechromium-app.sh --allow-adhoc` | valid on disk, DR satisfied (ad-hoc only) |
| Preflight | `scripts/preflight-hivechromium-app.sh` | PASS (5 CEF helpers, resource bundle) |
| Smoke | `scripts/smoke-test-hivechromium-app.sh` | PASS (readiness ≤ 60s) |
| Entitlements | `scripts/verify-hivechromium-entitlements.sh` + fixtures | PASS |
| Debug bundle + CDP | `swift package cef bundle ... --configuration debug` | fresh launch → exactly **1** page target |
| `hive://start/` rendering | CDP `Runtime.evaluate` | title "New Tab — Hive", 6972 DOM bytes, `window.cefSwift` present |
| Bridge | CDP `fetch('hive://start/')` | HTTP 200 |
| HTTPS navigation | CDP `window.location` → example.com | "Example Domain" |
| History | CDP `history.back()` | returns to `hive://start/` |
| Session persistence | session.json | exactly 1 `tabInfo` after fresh launch |
| Crash recovery | SIGKILL + relaunch | 1 tab restored at `hive://start/` |
| Corrupt session | invalid JSON in session.json + relaunch | recovers to defaults, 1 tab, no crash |
| Security | secrets grep, debug port gating, log sweep | clean |

## Fixes shipped

1. **Bug A (duplicate start tab):** `setupDefaults()` no longer calls
   `newTab()` after `createDefaultProfiles()` — `ChromiumBrowserState.swift`.
2. **Bug B (`ERR_UNKNOWN_URL_SCHEME` on `hive://`):** CefSwift vendored at
   `Vendor/CefSwift` (MIT, pinned); scheme handlers registered on the global
   context are replayed onto every per-profile request context at creation —
   `CefProfile.createContext()` + `CefRuntime.registerSchemeHandler`.

## Known limitations (accepted)

- Release artifact is ad-hoc signed for local development only; distribution
  requires a Developer ID + notarization.
- UI-level adversarial ops (rapid tab create/close, drag reorder, keyboard
  shortcuts) and a visual/a11y pass still need a human with eyes:
  `dist-debug/HiveChromium.app`, `CFFIXED_USER_HOME=<temp>` to isolate.
  Screenshot evidence: `.hive/mission/evidence/window-t05.png`.
- The app intentionally ignores external termination (SIGTERM, Apple Events
  quit); it quits via Cmd+Q (`saveNowAndQuit`).
- `hive-train/` (18 GB) and `RECOVERED:USABLE:COPYABLE CONTENTS/` (2 GB) are
  gitignored, not part of the repo.

## Ship state

Clean commit history on `mission/recovery-and-ship` (4 commits over the
single-commit `78d20f7` baseline). Not pushed; remote exists at
`https://github.com/arpituppal2/Hive.git`.
