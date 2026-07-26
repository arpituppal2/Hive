# Hive Browser — Architecture Decision Record
## Rendering Engine: WKWebView vs Chromium Embedded Framework (CEF)

**Status:** DECIDED (WKWebView primary, CEF adapter path documented)  
**Date:** 2026-07-16  
**Author:** Hive Browser Engineering  
**Supersedes:** None  
**Stakeholders:** Browser, Swarm, Honeycomb, Bee System

---

## Context

Hive Browser is a macOS-native browser that competes with Chrome, Safari, Arc, Zen, Vivaldi, Dia, and Brave. It is not a general-purpose browser clone — it is a knowledge-native workspace where browsing becomes persistent memory and structured action through Swarm's integrated AI layer.

The rendering engine choice determines:
- What web standards Hive supports
- Whether browser extensions (Chrome Web Store) work
- Developer tooling quality (DevTools)
- Energy efficiency on Apple Silicon
- Sandboxing posture and App Store eligibility
- Maintenance burden on the engineering team
- Download size and update cadence

---

## Options Considered

### Option A: WKWebView (Current)

**What it is:** Apple's system-native WebKit framework, used by Safari, Orion, and all macOS/iOS apps that embed web content.

**Capabilities:**
- Native macOS integration (iCloud Keychain, Apple Pay, Passkeys via ASAuthorization)
- Zero binary size impact (system framework, updated by macOS)
- Best-in-class Apple Silicon energy efficiency (hardware-accelerated power management)
- Full App Sandbox compatibility
- Nitro JavaScript engine (JIT-compiled, optimized for Apple hardware)
- Process-per-tab isolation via WKProcessPool
- Content blocking via WKContentRuleList (declarative, performant)
- Safari Web Inspector for debugging

**Limitations:**
- **No WebExtensions API** — cannot run Chrome extensions (1Password, uBlock Origin, React DevTools, etc.)
- DevTools are Safari's Web Inspector, not Chrome DevTools
- Limited to Apple's WebKit release cadence (tied to macOS updates)
- No cross-platform story (macOS only)

### Option B: Chromium Embedded Framework (CEF)

**What it is:** An open-source framework that embeds the full Chromium browser engine into native applications. Used by Spotify, Steam, Adobe products, and some niche browsers.

**Capabilities:**
- Full Chrome DevTools suite
- WebExtensions API support (Chrome extension compatibility)
- V8 JavaScript engine
- Cross-platform (macOS, Windows, Linux)

**Limitations:**
- **Massive binary footprint:** 200MB+ per application, increasing with every Chromium release
- **High maintenance burden:** Requires constant rebasing against Chromium upstream (weekly security patches, quarterly major releases). A dedicated engineer is needed full-time.
- **Poor energy efficiency:** Does not leverage Apple Silicon power management. Each CEF instance runs a full Chromium process tree.
- **Complex sandboxing:** CEF's sandbox model conflicts with macOS App Sandbox. Requires manual renderer process isolation.
- **No native macOS integration:** iCloud Keychain, Apple Pay, Passkeys require custom bridging code (months of engineering work)
- **Slow startup:** Cold-starting a CEF-based app takes 3-5x longer than WKWebView
- **Distribution friction:** Notarization is harder with bundled Chromium binaries. App Store review is unlikely to pass.

### Option C: Dual-Engine (WKWebView + CEF adapter path)

**What it is:** WKWebView for all standard browsing, with an abstraction layer that allows swapping to CEF for specific tabs/sites that require extension support.

This is documented as the **migration path** if WKWebView's extension limitation becomes a blocker for user adoption post-launch.

---

## Decision

**We choose Option A (WKWebView) as the primary engine, with Option C (dual-engine adapter path) as the documented fallback.**

### Rationale

1. **The browser is the wedge, not the product.** Hive's unfair advantage is Swarm's integrated intelligence (Honeycomb memory, Bee workers, Briefs, Flows). The rendering engine is infrastructure — it needs to be fast, efficient, and zero-maintenance. WKWebView delivers all three.

2. **Extension support can be addressed differently.** The Dia/Arc approach (custom "Boosts" via CSS/JS injection) plus built-in capabilities (ad blocking, tracker blocking, reader mode, password management via iCloud Keychain) covers 80%+ of user extension needs. For the remaining 20%, we document the CEF adapter path and revisit when user data justifies the engineering cost.

3. **Apple Silicon efficiency is a competitive advantage.** Safari users routinely report 2-4x better battery life than Chrome users. Hive can match Safari's efficiency while offering better organization (Hives/Workspaces) and intelligence (Swarm). CEF would forfeit this advantage.

4. **Zero maintenance cost.** WKWebView is updated by macOS. No rebasing, no security patches to ship, no 200MB+ binary bloat. This lets the team focus on what matters: Hive's differentiated features.

5. **App Store eligibility.** WKWebView passes App Sandbox review. CEF likely would not. While Hive ships primarily as a DMG, optional App Store distribution expands the user base.

6. **Startup time matters.** Hive must feel instantaneous. WKWebView cold-starts in <500ms on Apple Silicon. CEF takes 2-3 seconds minimum.

### What We Lose (and Why It's Acceptable)

| Loss | Mitigation |
|------|------------|
| Chrome Web Store extensions | Built-in ad/tracker blocking, reader mode, custom CSS/JS Boosts, iCloud Keychain autofill |
| Chrome DevTools | Safari Web Inspector for most workflows; document CEF adapter for teams that require full DevTools |
| Cross-platform (Windows/Linux) | macOS-first strategy per charter; cross-platform is not a current goal |
| WebExtensions API for Bees | Bees inject JS via WKUserScript, not extension APIs; this is cleaner and more secure |

### Migration Trigger (When to Adopt Option C)

The CEF adapter path is activated if **all** of the following are true:
1. Hive has >10,000 daily active users
2. User research shows extension support is the #1 reason for churn to Chrome/Arc
3. The engineering team has bandwidth for a dedicated CEF rebase engineer (estimated: 0.5 FTE minimum)
4. At least 6 months of runway before the next major release

Until then, the dual-engine abstraction boundary is maintained in the codebase (see `Sources/HiveBrowser/Models/BrowserTab.swift` — the `renderingEngine` protocol is designed for engine-agnostic tab operations), but CEF integration is not implemented.

---

## Consequences

### Positive
- Zero binary size impact for the rendering engine
- Best-in-class Apple Silicon battery life
- Native macOS integration (Keychain, Apple Pay, Passkeys) works out of the box
- No maintenance burden for security patches
- App Store eligibility preserved
- Fastest possible cold-start time

### Negative
- No Chrome Web Store extension support
- Safari Web Inspector instead of Chrome DevTools
- macOS-only (no cross-platform story)
- WebKit bugs are fixed on Apple's timeline, not ours

### Neutral
- Content blocking via WKContentRuleList (declarative, performant, but less flexible than uBlock Origin's dynamic filtering)
- JavaScript execution via WKUserScript for Bee/agent page interactions (cleaner than extension-based injection)
- Reading mode, find-in-page, zoom — all built into WebKit

---

## References

- [WebKit Documentation](https://webkit.org/)
- [WKWebView Apple Developer Documentation](https://developer.apple.com/documentation/webkit/wkwebview)
- [Chromium Embedded Framework (CEF)](https://bitbucket.org/chromiumembedded/cef)
- [Orion Browser — WebExtensions on WebKit](https://kagi.com/orion/) (case study: Orion attempted WebExtensions emulation on WebKit; partial success but significant engineering investment)
- Dia Browser — uses WKWebView, does not support extensions (precedent for the Hive approach)
- Arc Browser — uses WKWebView + Chromium for specific features (dual-engine precedent)

---

## Changelog

| Date | Version | Change |
|------|---------|--------|
| 2026-07-16 | 1.0 | Initial ADR: WKWebView decided as primary engine, CEF adapter path documented |
