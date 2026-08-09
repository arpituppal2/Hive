# Hive Release Pipeline — What's Left, In Order

**Status:** v1.0.0 (build 124) — 1558 tests / 144 suites green, CI/CD green.
Everything below is **release-critical and unfinished**, ranked by value.

---

## The three real blockers (not the CSS treadmill)

The CSS/test work is done and validated. These are the three things that
separate "a repo with a browser" from "a downloadable, updatable, notarized
browser":

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

### 3. 🟠 Adblock at the network layer — real engineering, no creds needed
`AdblockEngine.swift` + the staged `libhive_adblock_ffi.dylib` ship, but there
is **no call site**: vendored CefSwift exposes scheme handlers only, no
`CefRequestHandler`/`onBeforeResourceLoad` for arbitrary HTTP. Two paths:

- **A (recommended, medium): CefSwift request-handler extension.** Add a thin
  `CefRequestHandler` wrapper to `Vendor/CefSwift` (the C-API has it —
  `cef_request_handler_t` + `on_before_resource_load`), register it on the
  browser, call `AdblockEngine.shared.check(url:sourceHostname:requestType:)`,
  and cancel blocked loads with `ERR_ABORTED`. This makes blocking *real*
  (pre-request) instead of post-hoc.
- **B (quick, partial): CDP cosmetic injection.** The in-process CDP client
  works (`CDPClient` + `CefBrowser.sendDevToolsMessage`). On navigation finish,
  call `AdblockEngine.shared.cosmeticSelectors(for:)` and
  `Runtime.evaluate` a `<style>` that hides the returned selectors. Kills ads
  visually without touching the network. No load-event hook exists yet — add
  one where the CDP agent tools subscribe to `Page.loadEventFired`.

Until one lands, Hive blocks only the `EasyListBlocklist` fallback hosts. The
README/landing page honestly downgrade the claim.

---

## 4. 🟠 (later) BrowserState.swift decomposition
~7,000-line monolith. The eng review recommends extensions
(`+Tabs`, `+Workspaces`, `+AI`, `+Persistence`, `+Chrome`) before Phase-2
feature work so parallel agents stop colliding. Pure refactor — zero behavior
change, gated on the 1558-test suite.

---

## Standard release runbook

```bash
# 1. Full validation
swift test                                        # 1558 / 144

# 2. Local ad-hoc bundle (dev only — never distribute)
bash scripts/build-hive-app.sh --allow-adhoc
bash scripts/preflight-hive-app.sh --app dist/Hive.app --allow-adhoc
HIVE_SMOKE_TIMEOUT_SECONDS=60 bash scripts/smoke-test-hive-app.sh

# 3. REAL release (after creds are set)
HIVE_VERSION=1.0.1 HIVE_BUILD=125 \
  bash scripts/build-hive-app.sh                  # signs → dmgs → notarizes → staples

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
| `HIVE_WORKER_REQUIREMENT` / `HIVE_WORKER_TEAM_ID` | release worker auth |
| `DEVELOPER_ID_APPLICATION`, `APPLE_ID`, `APPLE_APP_PASSWORD`, `APPLE_TEAM_ID` | signing + notarization |
