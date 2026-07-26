# macOS 26+ Technical Research

> Filled incrementally across M0–M13 via WebSearch/WebFetch + Apple documentation (text-only).
> Each finding feeds directly into implementation decisions.

## Foundation Models Framework (macOS 26+)
- Framework API surface for on-device inference
- Model tiers: `.appleFMF`, `.appleFMFPlus`
- AIPolicy: untrusted context boundaries, prompt blocking rules
- Availability detection: `#available(macOS 26.0, *)` + runtime capability check
- Fallback: Intel Macs, AI-disabled, prompt-blocked → SwarmExecutor (localhost/BYOK)
- [ ] WebSearch: WWDC 2026 Foundation Models framework sessions
- [ ] WebSearch: Apple Developer documentation — FMF API surface

## Accessibility / UI Automation (Swarm M7)
- AXUIElement tree walker API: `AXUIElementCopyAttributeNames`, `AXUIElementCopyAttributeValue`
- Accessibility permissions: `AXIsProcessTrusted()` + `kAXTrustedCheckOptionPrompt`
- AppleScript/Automation: `NSAppleScript`, `OSAKit`, `SBApplication`
- ScreenCaptureKit: `SCStream`, `SCShareableContent` (text descriptions via OCR, not pixel sampling)
- [ ] WebSearch: macOS Accessibility API best practices for agentic automation
- [ ] WebSearch: ScreenCaptureKit text extraction capabilities

## App Sandbox Boundaries
- Sandbox prohibits: `NSTask`/`Process`, file writes outside container, Accessibility, AppleScript
- Sandbox allows: WKWebView, CloudKit, App-Group reads, Keychain, network requests
- Entitlement keys: `com.apple.security.app-sandbox`, `com.apple.security.files.user-selected.read-only`
- [ ] WebSearch: macOS App Sandbox entitlement reference (2026)
- [ ] Confirm: Developer ID notarization without sandbox (Cowork/Codex precedent)

## CloudKit + App-Group Seam (M0 foundation, M8 seam)
- CloudKit: `CKContainer`, `CKDatabase`, `CKRecord` — sandbox-safe, cross-device
- App-Group: `UserDefaults(suiteName:)`, shared container directory — same-machine low-latency
- Both apps share one CloudKit container (same team ID)
- [ ] WebSearch: CloudKit sharing between sandboxed + non-sandboxed apps (same team)
- [ ] Confirm: App-Group container works when one app is sandboxed and the other isn't

## WKWebView Internals (Hive Browser M1-M2)
- Persistent data store: `.default()` vs `.nonPersistent()` (never use nonPersistent)
- ITP (Intelligent Tracking Prevention): enabled by default in WKWebView
- Content blockers: `WKContentRuleListStore`, tracker lists
- Page text extraction: `WKWebView.evaluateJavaScript("document.body.innerText")`
- Chrome tab import: Chromium profile SQLite DBs (Bookmarks, Last Session, Current Tabs)
- [ ] WebSearch: WKWebView persistent store configuration for browser-class apps
- [ ] WebSearch: Chromium browser import — bookmarks/tabs file formats

## Swift 6 Strict Concurrency
- `@MainActor` for all UI types; `nonisolated` for snapshot handoffs
- `Sendable` conformance for cross-actor data types
- No GCD `DispatchQueue.main.async` for `self` captures
- `Task { @MainActor in }` for actor hops
- Enabled via `.enableUpcomingFeature("StrictConcurrency")` in Package.swift

## Distribution (M11)
- Notarization: `xcrun notarytool submit`, `xcrun stapler staple`
- DMG creation: `hdiutil create`, background image, alias to /Applications
- Developer ID signing: `codesign --sign "Developer ID Application: …"`
- Auto-update: hand-rolled version check against Hive website (no Sparkle)
- [ ] WebSearch: macOS notarization workflow 2026 (post-Xcode 26 changes)
- [ ] WebSearch: DMG creation best practices for developer distribution