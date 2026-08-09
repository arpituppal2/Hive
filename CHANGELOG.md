# Changelog

All notable changes to Hive Browser will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Hive adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [v1.0.0] — 2026-08-09 (build 100)

### Added
- **1349 tests** / 144 suites (+267 from 1082 baseline) — ALL PASSING
- **Chromium 148 backend** via CefSwift — native SwiftUI chrome shell
- **On-device AI** via Apple MLX — Model Council V2 (parallel multi-model with chair synthesis)
- **Agentic Browsing** — CDP-powered, 16-tool bridge surface with timeout guard
- **Deep Research** — multi-step plan/search/read/synthesize with live streaming
- **Zen CSS** (~15K chars ported): 100pt linear() easing, floating URL bar, compact mode, workspace dots, tab peek
- **Brave CSS** (~3K chars): Shields drop-down panel with stats grid
- **Dia CSS** (~7K chars): Typography (vw-based clamp), translucent card ::before bleed, chat swell/pile, dark mode, tab color tokens (18 variables from Assets.car)
- **Comet CSS** (~3K chars): Sidecar slide-in panel, collapsible reasoning chains, step status badges
- **Sidecar JS Bridge** — toggleSidecar() with Agent/Context/History tabs + addChainStep/Chain
- **Sidecar Swift Bridge** — hive.sidecar.open/close APIs + WebChromeSidecarStep/Chain
- **CI/CD Pipeline** — build + preflight + smoke + session-recovery all PASS
- **Vertical + horizontal tab layouts** with Arc-style compact mode
- **Workspaces/Spaces** — per-workspace profile isolation
- **Split view** with draggable dividers
- **Tab peek** — Arc-style hover preview + link peek
- **Private browsing** — ephemeral CEF profiles
- **Crash-only session persistence** — session.json + session.prev.json with recovery notices
- **Command palette** + tab search + floating URL bar
- **Sparkle 2 auto-updates** — graceful degradation for ad-hoc builds
- **Landing page** — web/index.html with download CTA
- **Waitlist, Privacy, Terms pages**
- **Product Hunt page** — web/ph.html with bento feature grid + founder note
- **Open Graph / Twitter Card meta tags**

### Changed
- HiveChromium → Hive — single executable target
- ChromiumBrowserState → BrowserState — all references unified
- Sources/HiveChromium/ → Sources/Hive/
- CSS styles.css: ~2,000 → ~31,000 chars (ported patterns from 5 browsers)
- WebChromeHandler: 60+ bridge registrations including full agent tool surface

### Fixed
- Duplicate start tab — setupDefaults() no longer double-calls newTab()
- ERR_UNKNOWN_URL_SCHEME — scheme handler replay on per-profile contexts
- CDP timeout guard — 15s timeout prevents AI loop deadlocks

### Security
- Keychain secret storage, CEF sandbox, Safe Browsing, EasyList blocking
- DevTools port #if DEBUG-gated, no secrets in repo

### Browsers Studied
- Zen (MPL-2.0): compact mode, tab peek, workspace dots, 100pt easing, URL bar
- Astro (MIT): CDP protocol codegen, browserOS agent architecture
- Brave (MPL-2.0): Shields panel, adblock patterns
- Dia.app: Typography, translucent cards, chat swell, dark mode, color tokens
- Comet.app (Perplexity): Sidecar agent panel, Chromium 150, SSE+WebSocket

[v1.0.0]: https://github.com/arpituppal2/Hive/releases/tag/v1.0.0