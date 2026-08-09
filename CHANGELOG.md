# Changelog

All notable changes to Hive Browser will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Hive adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v1.0.0] — 2026-08-09

### Added
- **Chromium 148 backend** via CefSwift — native SwiftUI chrome shell, not Electron
- **On-device AI** via Apple MLX — zero latency, data stays local on Apple Silicon
- **Model Council V2** — parallel multi-model dispatch (MLX-local, Tavily, BYOK, Vane) with chair synthesis
- **Agentic Browsing** — CDP-powered, AI navigates on your behalf (16-tool bridge surface)
- **Deep Research** — multi-step plan into search into read into synthesize with live streaming progress
- **Vertical + horizontal tab layouts** — toggleable, with Arc-style compact mode
- **Workspaces / Spaces** — per-workspace cookie/storage isolation
- **Split view** — side-by-side and top-bottom with draggable dividers
- **Tab peek** — Arc-style hover preview + link peek
- **Private browsing** — ephemeral CEF profiles
- **Hibernation policy** — memory saver for inactive tabs
- **Crash-only session persistence** — session.json + session.prev.json with recovery notices
- **Brave-level adblocking** — Rust engine with CNAME uncloaking + cosmetic filtering
- **Command palette** + tab search + floating URL bar
- **Reader mode + translate bar + find bar**
- **Bookmarks manager** — import/export, drag reorder
- **History panel + Downloads manager**
- **Settings** — appearance, search engines, commands, privacy, performance
- **Extensions toolbar** — placeholder for CEF extension API maturity
- **Media mini-player** — with PiP fallback
- **Safe Browsing** — 4-byte hash prefix lookups to Google
- **EasyList tracker blocking** + Global Privacy Control header
- **Keychain secret storage**
- **Sparkle 2 auto-updates** — graceful degradation for ad-hoc builds
- **Keyboard shortcut parity** — Chrome/Safari/Arc/Zen/Brave/Firefox
- **Landing page** — web/index.html with download CTA
- **Waitlist page** — web/waitlist.html with email capture
- **Privacy policy + Terms of service** pages
- **Sparkle appcast** — auto-update feed
- **GitHub Pages deployment** — arpituppal2.github.io/Hive
- **Open Graph / Twitter Card meta tags** — social sharing previews
- **LAUNCH_COPY.md** — Show HN, Product Hunt, Reddit launch copy
- **PRELAUNCH.md** — 7-section pre-launch checklist
- **CHANGELOG.md** — Keep a Changelog format

### Changed
- **HiveChromium into Hive** — single executable target, legacy WKWebView removed
- **ChromiumBrowserState into BrowserState** — all internal references unified
- **Moved Sources/HiveChromium/ into Sources/Hive/**
- **Build scripts renamed**

### Fixed
- **Duplicate start tab** — setupDefaults() no longer double-calls newTab()
- **ERR_UNKNOWN_URL_SCHEME** — scheme handlers replayed onto per-profile contexts
- **CDP timeout guard** — 15s timeout prevents AI loop deadlocks
- **Tab close cross-target commands** — graceful CDP handling

### Tests
- **1284 tests / 144 suites** — all passing (up from 1082 baseline, +202 verified)
- Every CaseIterable type verified non-empty
- Every public struct init verified for field preservation
- Bundle + smoke tests pass on every commit

### Security
- Entitlement verification fixtures pass
- DevTools port 9223 #if DEBUG-gated
- No secrets in Sources, scripts, or repo
- API keys env-injected via KeychainSecretStore
- CEF sandbox + helper processes
- Hardened runtime entitlements

[v1.0.0]: https://github.com/arpituppal2/Hive/releases/tag/v1.0.0
