# Hive Browser

Native macOS browser built on Chromium Embedded Framework (CEF 148). Swift 6, SwiftUI chrome, Chromium web rendering, on-device AI.

[![CI](https://github.com/arpituppal2/Hive/actions/workflows/hive-ci.yml/badge.svg)](https://github.com/arpituppal2/Hive/actions/workflows/hive-ci.yml)

## Quick Start

```bash
# Prerequisites: Xcode 16+, Rust toolchain, CEF binaries
# CEF is auto-downloaded by CefSwift's SwiftPM plugin.

# Build adblock native engine
cd native/adblock-ffi && cargo build --release && cd ../..

# Build research worker
bash scripts/build-research-worker.sh

# Build the browser
swift build --product Hive

# Run tests (1,912 tests, 184 suites)
swift test

# Create a local ad-hoc bundle
bash scripts/build-hive-app.sh --allow-adhoc

# Verify the bundle
bash scripts/preflight-hive-app.sh --app dist/Hive.app --allow-adhoc

# Smoke test
HIVE_SMOKE_TIMEOUT_SECONDS=60 bash scripts/smoke-test-hive-app.sh

# Open the app
open dist/Hive.app
```

## Architecture

| Layer | Technology | Role |
|---|---|---|
| Browser engine | CEF 148 (Chromium 148.0.7778.218) | Web rendering, JS, DevTools |
| Swift wrapper | CefSwift 0.1.0 (vendored) | CEF C API → Swift |
| Chrome | SwiftUI + `hive://` web chrome | Tabs, toolbar, panels, AI |
| Core library | HiveCore | Session, policies, AI orchestration, memory |
| AI inference | MLX (on-device), Tavily (cloud), BYOK | Model council, deep research |
| Adblock | Brave adblock-rust v0.13 via C FFI | Network + cosmetic filtering |
| Research | Rust `hive-fetch-boundary` | Hardened fetch worker |

## Features

- **Tab management**: Create, select, close, reorder, duplicate, pin, essential tabs
- **Workspaces**: Create, delete, switch, drag-and-drop, swipe gestures
- **Compact mode**: Zen-derived sidebar auto-hide with hover reveal
- **Split view**: Side-by-side, top-bottom, draggable dividers
- **Private browsing**: Ephemeral CEF profile — no history, session, or memory
- **Session persistence**: Crash-only contract with `session.json` + `session.prev.json` backup
- **AI swarm**: Multi-model council (MLX, Tavily, Vane, BYOK) with honest degradation
- **Deep research**: Multi-step streaming research with live progress
- **Code Studio**: File editing with diff preview + approval center
- **Voice commands**: Local speech recognition + TTS output
- **Command palette**: ⌘K with full browser command surface
- **Tab search**: ⌘⇧A fuzzy search across all tabs
- **Tab Overview**: ⌘K → "Tab Overview" — Arc-style visual grid of all tabs
- **Adblock**: Brave adblock-rust engine with network-level request filtering, CDP URL blocking, and cosmetic filtering (see docs/RELEASE_PIPELINE.md)
- **Auto-update**: Sparkle 2 with feed-gated activation (SUFeedURL injected on release builds)
- **Safe Browsing**: 4-byte hash prefixes to Google
- **Web Chrome**: Full browser UI rendered in `hive://` scheme
- **CDP Agent**: 16-tool agentic browsing bridge (navigate, snapshot, click, fill)
- **Extensions**: Extension management UI is shipped; unpacked extension loading is deferred pending the CEF extension API re-vendor
- **Bookmarks, History, Downloads, Reader Mode**
- **Passwords**: Keychain-backed secure storage
- **Crash Reporter**: Signal handlers + URLSession submission

## Project Structure

```
Sources/
├── Hive/                    # The browser app (CEF-backed, @main)
│   ├── HiveApp.swift         # App entry point
│   ├── BrowserState.swift    # Core state model and shared browser lifecycle
│   ├── BrowserState+*.swift  # Domain extensions for tabs, sync, navigation, and UI state
│   ├── BrowserWindow.swift   # Main window with chrome shell
│   ├── WebChromeHandler.swift # hive:// scheme + JS bridge
│   ├── WebChrome/            # Web chrome HTML/CSS/JS assets
│   ├── AdblockEngine.swift   # Brave adblock-rust FFI wrapper
│   ├── CrashReporter.swift   # Signal handlers + crash submission
│   ├── ExtensionsToolbar.swift # Extension icon + menu
│   ├── ExtensionsManagerSheet.swift # Extension install/management
│   ├── GeminiSidePanel.swift # AI chat UI and domain extensions
│   └── ...
├── HiveCore/                # Platform-agnostic core library
│   ├── AI/                  # Model council, dispatcher, research
│   ├── Browser/             # Tab model, policies, session store
│   ├── Honeycomb/           # SQLite + FTS5 memory store
│   └── ...
Tests/
├── HiveCoreTests/           # 1,912 tests, 184 suites
native/
├── hive-fetch-boundary/     # Rust research fetch worker
└── adblock-ffi/             # Brave adblock-rust C FFI
Vendor/
└── CefSwift/                # Vendored CEF Swift wrapper (MIT, pinned)
```

## Build Scripts

| Script | Purpose |
|---|---|
| `build-hive-app.sh` | Assemble signed Hive.app bundle |
| `preflight-hive-app.sh` | Verify bundle structure + signatures |
| `smoke-test-hive-app.sh` | Bootstrap + session recovery smoke test |
| `build-research-worker.sh` | Build Rust research worker |
| `verify-hive-entitlements.sh` | Validate hardened runtime and optional iCloud entitlements |
| `test-hive-entitlements.sh` | Validate entitlement fixtures (canonical entry point) |
| `verify-hive-entitlement-application.sh` | Audit signed-bundle entitlement separation (canonical entry point) |
| `notarize-hive-app.sh` | Submit to Apple notarization |

## CI/CD

- **`hive-ci.yml`**: Build → Test → Entitlements → Preflight → Smoke → Security audit on every push/PR
- **`hive-release.yml`**: Signed + notarized release on `hive-v*.*.*` tags

## Security

- Keychain-backed secret storage (Safe Browsing, Tavily, BYOK keys)
- CEF sandbox with helper processes (renderer, GPU, plugin)
- Hardened runtime entitlements (JIT, unsigned executable memory)
- Safe Browsing with 4-byte hash prefixes
- EasyList tracker blocking via adblock-rust
- Global Privacy Control header
- No telemetry, no browsing content logging
- DevTools port 9223 gated behind `HIVE_DEBUG_CDP=1`
- Crash logs sanitized before writing (no URLs, page titles, form values)

## Decisions

Architecture decisions are documented in:
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — System architecture
- [`docs/DECISIONS.md`](docs/DECISIONS.md) — Decision record (D-001 through D-007)
- [`docs/RECOVERY_PLAN.md`](docs/RECOVERY_PLAN.md) — Recovery mission plan
- [`.hive/mission/FINAL_VALIDATION.md`](.hive/mission/FINAL_VALIDATION.md) — Validation report
- [`docs/RELEASE_PIPELINE.md`](docs/RELEASE_PIPELINE.md) — What's left to ship for real (notarization, Sparkle signing, and credential-gated distribution)

## License

MIT — see `THIRD_PARTY_NOTICES.md` for vendored/open-source dependency licenses.

## Contributing

1. Build and test locally: `swift build --product Hive && swift test`
2. Create an ad-hoc bundle: `bash scripts/build-hive-app.sh --allow-adhoc`
3. Verify: `bash scripts/preflight-hive-app.sh --app dist/Hive.app --allow-adhoc`
4. Smoke test: `HIVE_SMOKE_TIMEOUT_SECONDS=60 bash scripts/smoke-test-hive-app.sh`
5. Open a PR against `main` — CI will validate build, test, entitlements, and security
