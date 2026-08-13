# Hive Browser — Recovery & Ship Mission

## Summary

This PR ships the Hive Browser: a complete Chromium-backed browser with AI swarm, adblock engine, Zen-derived compact mode, workspace DND, and agentic browsing via CDP.

**42 commits | 892 files | +214K/-5K lines**

## Architecture

- **Engine**: CEF 148 (Chromium 148.0.7778.218) via CefSwiftUI
- **Chrome**: Native SwiftUI shell + web content (hive:// scheme)
- **AI**: ModelCouncilV2, DeepResearch (streaming), CDP agent (16 tools)
- **Adblock**: Brave adblock-rust v0.13 via C FFI with cosmetic filtering
- **Security**: Keychain secrets, CEF sandbox, Safe Browsing, EasyList, GPC

## What Ships

| Capability | Status |
|---|---|
| Tab management (CRUD, reorder, duplicate, pin, essential) | ✅ |
| Workspaces/Spaces (DND, swipe, split view) | ✅ |
| Compact mode (Zen auto-hide/hover reveal) | ✅ |
| Private browsing (ephemeral CEF profile) | ✅ |
| Session persistence (crash-only contract) | ✅ |
| Bookmarks, History, Downloads, Reader Mode | ✅ |
| Safe Browsing + Adblock (cosmetic + network) | ✅ |
| AI Council + Deep Research + Code Studio | ✅ |
| Command Palette, Tab Search, Floating URL Bar | ✅ |
| Media Mini-Player, Crash Reporter, Voice Commands | ✅ |
| CDP Agentic Browsing (16-tool bridge) | ✅ |
| Settings, Zen theme tokens, Polar embedding, Morning Brief | ✅ |

## Validation

- swift build: Clean (0.51s)
- swift test: 1078 tests / 143 suites ✅
- bundle + adblock staging ✅
- preflight: 5 CEF helpers + adblock + worker ✅
- smoke: PASS (readiness ≤ 60s) ✅
- session recovery: PASS ✅
- codesign deep verify: 7 components ✅
- zero TODOs in source ✅
- secrets scan clean ✅

## CI/CD

- hive-ci.yml: Build → Test → Entitlements → Assembly → Smoke → Security audit
- hive-release.yml: Signed + notarized release on hive-v*.*.* tags

## Breaking Changes

- HiveChromium renamed to Hive; Sources/HiveChromium/ → Sources/Hive/
- Legacy WKWebView target removed; all script names updated
- All type names updated (ChromiumBrowserState → BrowserState, etc.)

## Checklist

- [x] Clean checkout builds
- [x] Full test suite passes (1078/143)
- [x] Smoke test passes
- [x] No security/privacy regression
- [x] External code provenance documented
- [x] Architecture, recovery, validation docs present
- [x] Git history coherent
- [x] Zero TODOs
- [x] CI/CD pipelines defined
