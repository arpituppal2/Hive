# Hive Recovery & Ship Plan

One-shot autonomous recovery: repair, verify, document, and ship the Hive
browser from the state found in the worktree (docs-only git history; product
source never committed; two live defects).

**Branch:** `main` (recovery-and-ship mission complete) — claims are separated into validated local evidence and explicit external/human limitations (`.hive/mission/baseline/`, `.hive/mission/evidence/`, `docs/DECISIONS.md`, `.hive/mission/FINAL_VALIDATION.md`). Current continuation edits are uncommitted; this plan does not claim a clean or coherent final history until they are reviewed and committed.

## Status

| Task | Scope | Status | Evidence |
| --- | --- | --- | --- |
| T001 | Repository census and baseline | ✅ | `.hive/mission/baseline/*.log` |
| T002 | Delete legacy Hive target | ✅ | `Package.swift`, `Sources/Hive/`; build/test green |
| T003 | Make HiveChromium the primary Hive target | ✅ | `Package.swift`, `Sources/Hive/`; restructure references fixed |
| T004 | Complete browser fundamentals | ✅ headless | tabs, workspaces, split view, navigation, persistence, CDP lifecycle |
| T005 | Fix HiveCore integration | ✅ | `Sources/HiveCore/`; latest suite 1,782/174 |
| T006 | UI/HIG/accessibility review and polish | ⚠️ human visual sign-off remains | `.hive/mission/evidence/window-t05.png`; headless validation cannot certify pixel fidelity |
| T007 | Security and privacy review | ✅ | entitlements/debug-port/secrets checks pass |
| T008 | Swarm/AI graceful degradation | ✅ | honest provider degradation and CDP regression coverage |
| T009 | Full test suite and validation | ✅ local validation | 1,782 tests / 174 suites; HiveCore/Hive product builds pass; current ad-hoc bundle, preflight, and 60s smoke readiness remain green |
| T010 | Documentation and final validation | ✅ docs current / history pending | current validation addenda and release boundary are documented; continuation edits remain uncommitted |

## Found defects (fixed)

- **Bug A — duplicate start tab on fresh launch.** `setupDefaults()` called
  `newTab()` after `createDefaultProfiles()` had already created one. Fixed by
  removing the duplicate calls.
- **Bug B — `hive://` and `cefswift://` failed with `ERR_UNKNOWN_URL_SCHEME`.**
  Tabs use per-workspace CefProfile request contexts; CEF scheme handler
  factories are per-context and not inherited. Fixed by vendoring CefSwift
  (pinned, MIT) and replaying registered handlers onto each new context.

## Remaining work / explicit limitations

1. **T05 sign-off** — a human visual pass on `window-t05.png` and the running
   app remains recommended; this environment cannot certify pixel fidelity or
   interactive HIG behavior without a display-driven UI harness.
2. **T04 UI adversarial remainder** — rapid tab create/close, reorder, and
   keyboard flows have headless/state coverage but still benefit from manual
   or display-driven interaction testing.
3. **Distribution release** — Developer ID signing, notarization, APNs/CloudKit
   provisioning, and Sparkle appcast signing remain credential-gated; the
   validated `dist/Hive.app` is ad-hoc and local-development-only.
4. **Extensions** — Chrome-style extension loading remains deferred pending a
   CEF re-vendor with extension headers; the current manager is intentionally
   honest about that capability boundary.


## Out of scope (noted)

- `hive-train/` (18 GB ML weights/pipeline) — gitignored, never versioned.
- Legacy WKWebView `Hive` target — **REMOVED**; replaced by Chromium-backed `Hive` target.
- Upstream CefSwift `main` (CEF 151) — no fix upstream; CEF 148 pinned.