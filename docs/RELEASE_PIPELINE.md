# Hive Release Pipeline — What's Left, In Order

**Status:** Local validation current — **1,635 tests / 157 suites green**, product build, ad-hoc bundle, preflight, and bootstrap smoke all pass. Distribution-only items below remain credential-gated and are not implied by the local artifact.

The remaining work is explicitly split between repository-complete validation and external release provisioning.

---

## Distribution blockers (external credentials, not local code defects)

The repository's local build/test/bundle/preflight/smoke path is green. These
are the remaining items that separate a locally validated ad-hoc artifact from
a downloadable, updatable, notarized browser:

### 1. 🔴 Notarization — needs your Apple credentials
Nothing code-wise remains; the pipeline exists end-to-end:

| Piece | Status |
|---|---|
| `scripts/notarize-hive-app.sh` (notarytool submit + wait + staple) | ✅ exists, wired into non-adhoc builds |
| `scripts/build-hive-app.sh` release path (sign → dmg → notarize → staple) | ✅ wired |
| Entitlements (`Sources/Hive/Hive.entitlements`) | ✅ hardened-runtime policy reviewed |
| Credentials (Developer ID, APPLE_ID, APPLE_APP_PASSWORD, TEAM_ID) | ❌ **blocked on you** |

**You need:** Apple Developer Program membership ($99/yr), then export:
```bash
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID12345)"
export APPLE_ID="you@example.com"
export APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"   # app-specific password
export APPLE_TEAM_ID="TEAMID12345"
```

### 2. 🔴 Sparkle feed signing — needs the notarized .dmg (build 1 first)
The app *can now* receive the feed (SUFeedURL injection landed), but Sparkle 2
refuses an appcast with an empty `sparkle:edSignature`. The signature comes
from Sparkle's `generate_appcast` on the **signed** .dmg — so this is gated on
#1.

```bash
# After a real release build:
generate_appcast --download-url-prefix \
  https://github.com/arpituppal2/Hive/releases/download \
  dist/
# Paste the printed sparkle:edSignature into web/appcast.xml, then redeploy.
```

The Sparkle EdDSA private key lives in the keychain item **"Sparkle 2 Private Key"**
on whatever machine runs `generate_appcast`. Back it up with the release owner —
future releases can't sign appcasts without it.

### 3. ✅ Adblock at the network layer — IMPLEMENTED (request + cosmetic + CDP)

**Both paths shipped, verified end-to-end:**

- **Path A — pre-request blocking (CefKit, IO thread):** `Vendor/CefSwift` now
  wires `cef_request_handler_t::get_resource_request_handler` (the CEF-148
  replacement for `on_before_resource_load`) in `BrowserClient.makeRequestHandler()`.
  A thread-safe global filter (`CefKit/CefResourceFilter.swift`, NSLock-guarded,
  never hops to the main thread) is consulted for every resource load; blocked
  URLs get a `cef_resource_request_handler_t` whose `on_before_resource_load`
  returns `RV_CANCEL`, dropping the request before it hits the network.
  The predicate is installed once at startup by `BrowserState.installNetworkAdBlockFilter()`
  and ships the static, subdomain-aware `AdBlockPolicy.shouldBlockNetworkHost`
  matcher over `EasyListBlocklist.domains` (honoring the `HiveAdBlockEnabled`
  UserDefaults toggle). The Rust engine (`AdblockEngine.shared.check`) remains
  the cosmetic-selector path.
- **Path B — CDP `Network.setBlockedURLs`:** applied per-browser in
  `applyAdBlockPolicy(to:)` on every `wireCDP` (pre-request at the Chromium
  layer, subdomain patterns from `AdBlockPolicy.cdpURLPatterns`).
- **Cosmetic hiding:** `applyCosmeticAdBlock` injects the Rust engine's CSS
  selectors after each navigation via the existing `executeJavaScript` probe
  path.

Settings → Privacy → "Block ads & trackers" toggles all three.

**Remaining (optional, later):** consult the Rust engine (`AdblockEngine.shared.check`)
per request instead of the static set — the `CefResourceFilter` predicate is the
single seam where that drops in.

---

## 4. ✅ BrowserState.swift decomposition — DONE
`BrowserState.swift` was split from 7,128 → 1,415 lines into 23 domain
`BrowserState+<Domain>.swift` extensions (`scripts/split_browser_state.py`,
commit `eb3506fd`). `GeminiSidePanel` (1,921 → 281), `WebChromeHandler`
(1,319 → 802, DTOs + agent tools carved), `SheetsPanelView` (938 → ~100 +
10 extensions), and`SettingsView` (770 → 83 + 7 extensions) followed with `scripts/split_swift_type.py` (commit `371fddcd`). These were pure refactors with zero behavior change; the decomposition checkpoint had 1,567 tests, and the current suite is 1,635 tests / 157 suites.

---

## 5. 🟠 P1.8 — Chrome-style extensions: DECISION (deferred, needs CEF re-vendor)

Feasibility verdict (2026-08-09): **CEF 148 can load unpacked Manifest-V3
extensions** via `cef_request_context_t::load_extension` (requires a persistent
`cache_path`), but the **vendored CefSwift distribution ships NO extension C
API headers** (`cef_extension_t`/`cef_extension_handler_t`/`load_extension` are
absent from `Vendor/CefSwift/Sources/CCef/include/include/capi/`). Two
consequences:

- **Blocked now:** building a loader requires re-vendoring a CEF distribution
  that includes the extension headers + wrapping the callbacks in CefSwift — a
  heavy, release-blocking operation on the pinned CEF 148. Deferred.
- **Scope reality:** even after a re-vendor, CEF is **sideload-only** for
  unpacked extensions. There is **no Chrome Web Store integration** (no remote
  install, no CWS auto-update, no store purchase flow), and several `chrome.*`
  APIs that rely on Google backends (`chrome.identity`, `chrome.storage.sync`)
  will not function. The roadmap's "Chrome Web Store bridge (5 days)" is not
  achievable in CEF; the honest ship scope is **local unpacked loading + a
  management UI**, and even that is gated on the re-vendor.

The toolbar already handles the honest case (pinned icons open the extensions
manager; nothing pretends to be a live extension).

---

## Standard release runbook

```bash
# 1. Full local validation
swift build --product Hive
swift test                                        # 1635 / 157
# Current validation also runs both product builds before packaging.

# 2. Local ad-hoc bundle (dev only — never distribute)
bash scripts/build-hive-app.sh --allow-adhoc
bash scripts/preflight-hive-app.sh --app dist/Hive.app --allow-adhoc
HIVE_SMOKE_TIMEOUT_SECONDS=60 bash scripts/smoke-test-hive-app.sh

# 3. REAL release (after creds are set)
# CloudKit is optional. The checked-in entitlements are intentionally
# CloudKit-disabled. To enable sync, create a release-only entitlements file
# from the checked-in file and add the matching iCloud container capability:
cp Sources/Hive/Hive.entitlements /tmp/Hive.release.entitlements
# Add these keys to /tmp/Hive.release.entitlements using Xcode's Signing & Capabilities
# (or PlistBuddy), replacing the example identifier with your provisioned value:
#   com.apple.developer.icloud-container-identifiers = ( iCloud.com.hive.browser )
#   com.apple.developer.icloud-services = ( CloudDocuments, CloudKit )
# Then build with the exact same identifier:
HIVE_CLOUDKIT_CONTAINER=iCloud.com.hive.browser \
HIVE_VERSION=1.0.1 HIVE_BUILD=125 \
  bash scripts/build-hive-app.sh --entitlements /tmp/Hive.release.entitlements # signs → dmgs → notarizes → staples

# 4. Sparkle appcast
generate_appcast --download-url-prefix https://github.com/arpituppal2/Hive/releases/download dist/
#   → paste sparkle:edSignature into web/appcast.xml (version must equal HIVE_BUILD)

# 5. Ship
#   - Upload dist/Hive.dmg to the GitHub release
#   - Deploy web/appcast.xml to GitHub Pages (the SUFeedURL target)
```

## Env vars used by the build
| Var | Purpose |
|---|---|
| `HIVE_VERSION` | CFBundleShortVersionString (e.g. 1.0.1) |
| `HIVE_BUILD` | CFBundleVersion — must match `sparkle:version` |
| `HIVE_APPCAST_URL` | overrides the default GitHub Pages appcast URL |
| `HIVE_CLOUDKIT_CONTAINER` | optional; enables sync only in a non-ad-hoc build when `--entitlements` contains the same `iCloud.*` identifier |
| `HIVE_WORKER_REQUIREMENT` / `HIVE_WORKER_TEAM_ID` | release worker auth |
| `DEVELOPER_ID_APPLICATION`, `APPLE_ID`, `APPLE_APP_PASSWORD`, `APPLE_TEAM_ID` | signing + notarization |
