# Hive Production Readiness Report

Generated: 2026-06-24

## Completed Changes

### P0 Blockers
- Unified onboarding persistence via `HiveOnboardingStore` (`hive.onboarding.completed`) with legacy key migration
- Wired Settings **Export all data**, **Run Integrity Check**, and **Reset Hive** (two-step confirmation + sqlite backup)
- Source plugin toggles persist per-plugin and trigger folder bookmark flows on macOS
- Settings Source Plugins panel is scrollable; paste bar supports Return/submit with plugin validation errors
- Widget timeline reads live snapshot from `HiveWidgetSnapshotStore` (written on each store refresh)
- iPhone composer supports injected send/voice/attach handlers and capability-aware placeholder text

### Architecture
- `CapabilityDetector` + `CapabilityStore` for Apple Intelligence / CoreML / watch relay tiers
- `HiveStore.inTransaction` for atomic rollback semantics
- `HiveWorkspaceOperations` for export, integrity check, and full workspace reset
- `HiveWatchConnectivityHandler` for watch → iPhone query relay
- `HiveKeychainStore` + `GoogleDriveOAuthStore` for credential storage

### UI System
- `AnimationKit` with reduced-motion compliance and page transition helpers
- Liquid Glass surfaces already present via `HiveLiquidGlassSurface`; page transitions use `AnimationKit`
- Swarm shows API-key banner when running in CoreML distilled tier

### Integrations
- Plugin toggle store with Keychain-ready Google Drive token storage
- Widget snapshot bridge between app and WidgetKit provider
- Watch ask page sends queries via WatchConnectivity + App Intents fallback

### Multi-Platform
- Watch ask flow updated for iPhone relay and deep link handoff
- Mobile composer callback architecture for host app wiring
- `scripts/generate_xcode_project.sh` documents Xcode scheme setup

### Tests Added
- Onboarding key unification
- Plugin toggle persistence
- Paste input classifier
- Widget snapshot round-trip
- SQLite transaction rollback

## Unresolved Blockers

| Blocker | Reason | Required Action |
|--------|--------|-----------------|
| Xcode/macOS build validation | Cloud agent runs Linux; `swift` toolchain unavailable | Open `Package.swift` in Xcode 16 on macOS; run schemes for macOS, iPhone, iPad, Watch |
| Google Drive OAuth UI flow | Requires `ASWebAuthenticationSession` + registered OAuth client | Configure Google OAuth client ID in build settings; wire session in plugin toggle ON handler |
| Apple Intelligence runtime probes | Foundation Models APIs require macOS 26 / iOS 26 SDK on device | Validate `CapabilityDetector` on M-series hardware with Apple Intelligence enabled |
| Full graph AppKit canvas (Prompt 1b) | Spec requests `NSScrollView` + `HiveGraphCanvasView`; current graph is SwiftUI/Metal hybrid | Dedicated graph canvas migration remains a follow-up |
| Icon Composer asset pipeline | Requires macOS Icon Composer + Figma export | Run icon generation per spec PART 1 |
| Impeccable design detector | Requires `npx impeccable` on macOS | Run before release merge |

## Test Matrix

| Area | Automated | Manual (Xcode) | Status |
|------|-----------|----------------|--------|
| Onboarding once-only | `testOnboardingStoreUsesSingleCompletedKey` | Launch app 5× after completing onboarding | Code ready |
| Settings export/reset | `testStoreTransactionRollsBackOnFailure` | Export via panel; reset with double confirm | Code ready |
| Plugin toggles | `testSourcePluginToggleStorePersistsPerPlugin` | Toggle each plugin; verify Keychain/bookmarks | Partial (OAuth pending) |
| Paste bar classifier | `testPasteInputClassifierDetectsDriveAndWebURLs` | Paste Drive/URL/local path in Settings | Code ready |
| Widget live data | `testWidgetSnapshotStoreRoundTrip` | Add source; verify widget updates within 30 min | Code ready |
| Capability tiers | — | Test on AI-capable Mac vs Intel vs Watch | Code ready |
| Watch voice relay | — | Dictate on Watch; verify iPhone Swarm response | Code ready |
| iPhone portrait/landscape | — | iPhone 16 + SE simulators | Host wiring needed |
| Reindex atomicity | `testStoreTransactionRollsBackOnFailure` | Kill mid-reindex; verify DB unchanged | Partial |
| Swarm API key fallback | — | Disable AI; verify search-only + banner | Code ready |

## Production Readiness Verdict

**Not yet shippable** without macOS/Xcode validation pass. Core P0 wiring, architecture primitives, and regression tests are in place. Remaining work is platform-runtime verification, Google OAuth client configuration, graph AppKit migration, and visual asset pipeline.

## Recommended Next Steps on macOS

```bash
open Package.swift
swift test
scripts/acceptance.sh
scripts/build_app.sh release
```

Validate all four schemes (macOS, iPhone, iPad, Watch) per the multi-platform spec, then run the FINAL PROMPT integration suite (Tests I-1 through I-6 and Edge E-1 through E-8).
