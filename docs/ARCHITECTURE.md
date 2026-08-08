# Hive Browser — Architecture

Native macOS browser built on Chromium Embedded Framework (CEF). Swift 6,
SwiftUI chrome, CEF web content.

## Products and targets

| Target | Role |
| --- | --- |
| `Hive` | The shipping browser (CEF-backed). `@main` at `Sources/Hive/HiveApp.swift`. |
| `HiveCore` | Platform-agnostic core: browser model, session persistence, policies, AI/swarm orchestration, honeycomb memory. ~77 test files. |
| `HiveWebKitSmoke` | Opt-in dev smoke target (not a product). |

Third-party:
- **CefSwift** (MIT) — Swift wrapper over the CEF C API. **Vendored** at
  `Vendor/CefSwift` (pinned 0.1.0 @ `2dca11e`) with a local patch: scheme
  handlers registered on the global context are replayed onto every
  per-profile request context at creation (see `docs/DECISIONS.md` D-002).
  CEF binaries are downloaded and bundled by the `swift package cef` plugin.
- **mlx-swift-examples** — on-device LLM inference (`MLXLLM`/`MLXLMCommon`)
  for the Swarm. Falls back to Base/Mock providers when weights or keys are
  absent — never silent, never fake.
- **native/hive-fetch-boundary** (Rust) — hardened research fetch worker,
  built by `scripts/build-research-worker.sh` into the app bundle.

## Process model

`Hive.app` is a CEF *browser process*. Web content runs in CEF's own
helper (renderer) processes. The SwiftUI chrome (tabs, address bar, panels) is
native UI; the start page is web content served by the app itself.

## Web chrome: the `hive://` scheme

- `WebChromeBridge` (`Sources/Hive/WebChromeHandler.swift`) serves
  `hive://start/` (assets in `Sources/Hive/WebChrome/`) via
  `HiveSchemeHandler`.
- A per-session `sessionToken` is embedded in the start page; every JS→Swift
  bridge call (`hive.*`) must present it.
- `displayIsolated` prevents arbitrary sites from iframing the start page.
- The reserved `cefswift://bridge/*` scheme (from CefSwift) powers the
  Swift↔JS bridge; shim auto-injection is disabled — only the start page
  carries `window.cefSwift`.

## Profiles and isolation

- Each workspace maps to `CefProfile.persistent(name: <workspaceID>)` — its
  own cache dir under `<rootCachePath>/Profiles/<workspaceID>` (cookie/storage
  isolation). Private browsing uses `CefProfile.incognito()`.
- CEF does **not** inherit scheme handler factories from the global context
  into per-profile contexts; the vendored CefSwift replays them per context
  (D-002). Without this, `hive://` failed with `ERR_UNKNOWN_URL_SCHEME`.

## Session persistence

- `BrowserState` (the single source of truth) autosaves to
  `session.json` under Application Support; `session.prev.json` keeps the
  previous snapshot; corrupt files are quarantined, never silently reset —
  recovery surfaces through `SessionRecoveryBanner`/`SessionRepairNotice`.
- Quit path: Cmd+Q → `saveNowAndQuit()` (session + hot memory flush, then
  `NSApp.terminate`). The app cancels external termination requests.
- Crash recovery verified: SIGKILL + relaunch restores the pre-crash tabs.

## AI / Swarm (graceful degradation)

- Providers are keyed by environment (`TAVILY_API_KEY`) or on-device weights;
  when absent, runtime honestly reports Base/Mock providers (labelled, never
  silent).
- Research handoffs go through the Rust fetch boundary for isolation; the
  worker is packaged and code-sign-verified at release build time.

## Debug-only surface

- DevTools on `localhost:9223` is `#if DEBUG`-gated (never in release).
  Useful for headless verification via the CDP JSON API
  (`http://127.0.0.1:9223/json`).

## Build & verify (developer)

```sh
swift build --product Hive          # compile
swift test                          # 983 tests / 130 suites
swift package cef bundle --product Hive \
  --configuration debug --output dist-debug --bundle-id com.hive.browser.debug --sign -
scripts/build-hive-app.sh --allow-adhoc   # release app bundle
scripts/preflight-hive-app.sh             # packaging preflight
scripts/smoke-test-hive-app.sh            # two-launch smoke
```