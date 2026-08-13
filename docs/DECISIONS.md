# Hive Decision Record

Decisions made during the recovery-and-ship mission (`mission/recovery-and-ship`),
in reverse-chronological order. Each entry records the decision, the context,
and the evidence that drove it.

---

## D-002 (2026-08-07): Vendor CefSwift and replay scheme handlers per request context

**Decision.** Vendor CefSwift 0.1.0 (MIT, pinned upstream commit `2dca11e`) at
`Vendor/CefSwift`, switch `Package.swift` to the path dependency, and patch it so
every scheme handler registered on the global context is re-registered on every
per-profile request context at creation time.

**Context.** Tabs in workspaces use `CefProfile.persistent(name:)` request
contexts; private tabs use `CefProfile.incognito()`. Live CDP probing showed
`hive://start/` and even CefSwift's own `cefswift://bridge/ping` failing with
`ERR_UNKNOWN_URL_SCHEME` — CEF does not inherit scheme handler factories from the
global context, and CefSwift only registered on the global context
(`on_context_initialized` is a no-op).

**Alternatives considered.**
- Bump to upstream `main` (CEF 148 → 151, newer commits `68d1bec`/`3af1fbf`).
  Rejected: the upstream diff since 0.1.0 is CI/docs/CEF-version only — no
  scheme-handler fix exists upstream; a CEF major bump adds unbounded regression
  risk to a recovery mission.
- Route `hive://` through the global context only. Rejected: breaks the
  per-workspace storage isolation model the browser is built on.

**Implementation.** `CefRuntime.registerSchemeHandler` records each
(scheme, domain, handler) in a list; `CefProfile.createContext()` replays that
list onto each newly created context via `register_scheme_handler_factory`
(fresh `SchemeHandlerFactory` per context — each registration consumes its own
+1 ref). The reserved `cefswift` bridge scheme flows through the same path
(registered during `initialize`).

**Evidence.** `swift build` clean; 983 tests / 130 suites pass; on a fresh
isolated launch: exactly 1 page target, `hive://start/` renders (title
"New Tab — Hive"), `fetch('hive://start/')` returns 200, `window.cefSwift`
present, `session.json` records exactly 1 tab.

---

## D-001 (2026-08-07): Fresh launch must create exactly one tab

**Decision.** `setupDefaults()` must not call `newTab()` after
`createDefaultProfiles()` — the latter already creates the initial tab.

**Context.** CDP probing of a fresh isolated launch showed two page targets at
`hive://start`. Root cause: both `setupDefaults()` (line ~4177/4193) and
`createDefaultProfiles()` (line ~4347) created a tab.

**Evidence.** After removing the duplicate calls: fresh launch shows exactly
1 page target and 1 `tabInfo` in `session.json`.

---

## D-000 (baseline, 2026-08-07): Recovery starts from evidence

**Decision.** Treat the app's behavior, not its docs, as ground truth. Establish
a baseline (build, 983 tests, smoke), then probe live behavior via CDP on the
debug bundle before changing anything. Document every claim with logs.

**Evidence.** Baseline logs in `.hive/mission/baseline/`; live CDP verification
scripts and outcomes recorded in the mission ledger.
