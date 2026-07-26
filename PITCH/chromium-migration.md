# Chromium Dual-Engine Migration Architecture

**Status:** Plan — approved by /autoplan review  
**Decision:** Switch to Chromium Embedding Framework (CEF) for user-facing browsing; retain WKWebView for autonomous Bee/Agent web tasks.  
**Rationale:** Extension support is necessary for power-user adoption. WKWebView cannot support WebExtensions/Chrome extensions. Chromium provides full extension ecosystem. WKWebView is retained for headless agent tasks where its lightweight nature and macOS integration are advantages.

---

## Architecture Overview

```
┌──────────────────────────────────────────────────┐
│                  Hive Browser                     │
│                                                   │
│  ┌──────────────┐        ┌────────────────────┐  │
│  │ User Browsing │        │ Bee / Agent Tasks  │  │
│  │  (Chromium)   │        │   (WKWebView)      │  │
│  │               │        │                    │  │
│  │ • Extensions  │        │ • Headless capture │  │
│  │ • DevTools    │        │ • Page extraction  │  │
│  │ • Profiles    │        │ • Automated nav    │  │
│  │ • Sync        │        │ • Screenshot       │  │
│  │ • Passwords   │        │ • JS evaluation    │  │
│  └──────┬───────┘        └────────┬───────────┘  │
│         │                         │               │
│         └──────────┬──────────────┘               │
│                    │                              │
│            ┌───────┴───────┐                      │
│            │  HiveCore      │                      │
│            │  Memory/Wiki   │                      │
│            │  AI Dispatch   │                      │
│            │  Design Tokens │                      │
│            └───────────────┘                      │
└──────────────────────────────────────────────────┘
```

## Engine Selection Logic

| Context | Engine | Reason |
|---------|--------|--------|
| User tabs (normal browsing) | Chromium (CEF) | Extensions, DevTools, profiles |
| Private/Incognito tabs | Chromium (CEF) | Isolated storage, no extension access |
| Bee autonomous agents | WKWebView | Lightweight, macOS-native, no UI chrome needed |
| Page capture (⌘E) | WKWebView | Headless JS extraction, no rendering overhead |
| Reading Mode | WKWebView | Readability.js injection, DOM extraction |
| Swarm browser control | WKWebView | Programmatic navigation, no user session conflict |
| Web extension host page | Chromium (CEF) | Extension APIs require full Chromium |

## Chromium Embedding Options

| Option | Pros | Cons | Recommendation |
|--------|------|------|----------------|
| **CEF (Chromium Embedded Framework)** | Full Chromium, mature, C API, used by Spotify/Steam/VS Code | ~200MB binary, separate update cycle, Obj-C bridging | **Primary path** |
| **Electron** | Easy JS integration, large ecosystem | Heavy (~150MB base), Node.js dependency, security surface | ❌ Not suitable |
| **Chromium.framework** (custom build) | Direct embedding, smaller than CEF | Build complexity, maintenance burden, no official support | Fallback |
| **WebKit.framework** (Safari's engine) | Already on system, zero binary size | No extension support, same limitations as WKWebView | ❌ Same problem |

## Implementation Phases

### Phase 1: CEF Integration Spike (2-3 weeks)
- Integrate CEF via Swift Package or XCFramework
- Create `ChromiumWebView` NSViewRepresentable matching current `TabWebViewRepresentable` API
- Verify extension loading (Manifest V3)
- Smoke test: uBlock Origin, 1Password, React DevTools, Dark Reader
- Memory comparison: CEF vs WKWebView baseline

### Phase 2: Dual-Engine Tab Manager (2-3 weeks)
- `BrowserTab.engine` property: `.chromium` for user tabs, `.webkit` for agent tabs
- `TabWebViewRepresentable` dispatches to correct engine
- Shared cookie/storage isolation between engines
- Session restore across engine types
- Hibernation: CEF tabs use CEF's built-in discard, WKWebView uses existing `TabHibernationEngine`

### Phase 3: Extension Management (2 weeks)
- Extension store integration (Chrome Web Store via CEF APIs)
- Extension permission model + UI
- Per-tab extension enable/disable
- Extension conflict detection
- Import from existing Chrome/Edge/Brave profiles

### Phase 4: Migration Bridge (1-2 weeks)
- Import bookmarks, history, passwords from Chrome/Edge/Brave/Safari
- Profile migration wizard (part of OnboardingSheet)
- WKWebView session state translation to CEF
- Graceful fallback: if CEF unavailable, degrade to WKWebView for all tabs

### Phase 5: Polish & Ship (2 weeks)
- Auto-updater for CEF (Chromium security patches ship every 2 weeks)
- Crash reporting for renderer processes
- Memory pressure handling per-engine
- Performance regression testing

## Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| CEF binary size (~200MB) | DMG too large | Delta updates, lazy download on first launch |
| Chromium update cadence (every 2 weeks) | Maintenance burden | CI pipeline for CEF updates, automated testing |
| Extension compatibility (Manifest V3 only) | Some extensions won't work | Clearly communicate V3-only; fallback Web Store |
| Two rendering engines = 2x bug surface | QA complexity | Clear engine selection rules, engine-specific test suites |
| Memory overhead (Chromium + WKWebView) | High RAM usage | Aggressive hibernation, per-engine memory limits |

## Kill Criteria

If any of these occur during Phase 1, fall back to WKWebView-only:
- CEF binary exceeds 250MB compressed
- Extension loading fails for uBlock Origin, 1Password, or Bitwarden
- CEF rendering is perceptibly slower than WKWebView on same hardware
- Crash rate > 1% in smoke testing

## Open Questions

1. **App Store eligibility:** CEF-based apps can be notarized for DMG distribution. App Store requires sandboxing, which CEF may violate (renderer processes). Decision: DMG distribution only (already planned for unsandboxed Swarm).
2. **Sparkle vs CEF updater:** Should Hive's auto-updater update CEF, or should CEF self-update? Recommendation: Hive's Sparkle updater manages all binaries for consistency.
3. **WKWebView removal timeline:** If CEF works well, should WKWebView be removed entirely? Recommendation: Keep WKWebView for agent tasks indefinitely — it's a proven, lightweight, macOS-native engine for headless work.
