# Hive Browser Changelog

## v1.0.0 (2026-08-08)

### Core Browser
- **Engine**: Chromium 148 via CefSwiftUI, native SwiftUI chrome shell
- **Tab management**: Create, select, close, reorder, duplicate, pin/unpin, essential tabs
- **Workspaces**: Create, delete, switch (⌘⌥1-9), DND tab move, swipe gesture
- **Split view**: Side-by-side, top-bottom, draggable dividers
- **Compact mode**: Zen-derived sidebar auto-hide with hover reveal
- **Navigation**: Back, forward, reload, stop, address bar (⌘L)
- **Private browsing**: Ephemeral CEF profile
- **Session persistence**: Crash-only contract (session.json + backup)
- **Hibernation**: Memory saver for inactive tabs
- **Bookmarks/History/Downloads**: Full CRUD, import/export
- **Reader mode**: Content extraction + readability

### Web Chrome
- `hive://` scheme: Full browser UI rendered in web content
- JS↔Swift bridge: Session-token-gated `window.cefSwift.invoke`
- ARIA accessibility: Landmark roles (banner/search/complementary/main), live region, 175+ labels
- Per-workspace CEF profile isolation

### AI / Swarm
- **ModelCouncilV2**: Parallel multi-model dispatch (MLX/Tavily/Vane/BYOK) with chair synthesis
- **Deep Research**: Multi-step plan→search→read→synthesize with AsyncStream streaming
- **Honest degradation**: Mock providers when keys/weights absent — never silent, never fake
- **Voice command**: Speech recognition + TTS output
- **Code Studio**: File editing with diff preview + approval center

### Agentic Browsing (CDP)
- **16-tool surface**: Navigate, snapshot (AX tree), click, fill, type, scroll, screenshot, read, evaluate, grep, tabs, newTab, closeTab, activateTab, reload, wait
- CEF DevTools Protocol bridge with timeout guards

### Security & Privacy
- **Safe Browsing**: 4-byte hash prefixes to Google
- **Adblock**: Brave adblock-rust v0.13 via C FFI, cosmetic filtering
- **Keychain**: Secrets storage (Safe Browsing, Tavily, BYOK)
- **Hardened runtime**: JIT + unsigned executable memory entitlements
- **Global Privacy Control** header
- **No telemetry**, no browsing content logging

### Platform
- **Auto-update**: Sparkle 2.6 framework + settings UI + appcast.xml
- **Crash reporter**: Signal handlers + URLSession submission
- **Extension manager**: Install/uninstall/persist
- **Landing page**: Arch detection, download links, waitlist
- **Onboarding**: Browser import wizard + theme picker
- **Cross-device sync**: CloudKit engine (tabs, bookmarks, history) with push notifications
- **CI/CD**: hive-ci.yml + hive-release.yml

### Quality
- ****1204 tests** / 143 suites** — all passing
- **Zero TODOs/FIXMEs** in non-vendored Swift
- Bundle + smoke: PASS
- macOS 14.0+, Apple Silicon / Intel (Rosetta 2)

### Known Limitations
- Ad-hoc signing only (Apple Developer ID needed for notarization)
- MLX model weights ~300 MB download on first AI use
- CEF 148 pinned (upstream 151 lacks scheme-handler fix)
- Extensions gated on CEF extension API maturity

---

## Build

```sh
git clone https://github.com/arpituppal2/Hive.git
cd Hive
swift build --product Hive
swift test  # **1204 tests**
scripts/build-hive-app.sh --allow-adhoc
```

### v1.0.0 Post-Release Additions (2026-08-08)
- **Privacy Policy & Terms of Service** pages on landing site
- **Favicon** for landing page (honey-orange icon)
- **Sparkle appcast.xml** with real release metadata (file size, SHA-256, URL)
- **Theme toggle** in browser chrome (sun/moon, localStorage-persisted, light CSS tokens)
- **Honeycomb particle canvas** on start page and landing page
- **Scroll-triggered animations** on landing page (IntersectionObserver, staggered reveals)
- **Download URL wiring** to GitHub Release v1.0.0 assets
- **GitHub Release** v1.0.0 published with Hive.dmg (171 MB)
- **BrowserTab tests** (+3: isLoading, canGoBack, displayTitle)
- **SitePermissionPolicy test** (+1: allCases non-empty)
