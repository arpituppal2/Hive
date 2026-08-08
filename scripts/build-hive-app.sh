#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/dist"
SIGNING_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
TEAM_ID="${HIVE_WORKER_TEAM_ID:-${APPLE_TEAM_ID:-}}"
PRODUCT="Hive"
APP_NAME="Hive.app"
ALLOW_ADHOC=0
ENTITLEMENTS_PATH=""

usage() {
  cat <<'USAGE'
Assemble a signed Hive app bundle for local/release validation.

Usage:
  scripts/build-hive-app.sh [--output DIR] [--sign IDENTITY]

Options:
  --output DIR   Directory for Hive.app (default: ./dist).
  --sign ID      Developer ID Application identity. Defaults to
                 DEVELOPER_ID_APPLICATION.
  --allow-adhoc  Local development only: assemble with ad-hoc signatures and
                 a clearly marked non-release worker requirement. This skips
                 release-only Team ID/requirement verification and must never
                 be used for distribution.
  --entitlements PATH
                 Apply the reviewed hardened-runtime entitlements while
                 signing nested CEF code and the outer app.
  -h, --help     Show this help.

Required release inputs:
  HIVE_WORKER_REQUIREMENT  Exact designated requirement for the signed worker.
  HIVE_WORKER_TEAM_ID      Ten-character Apple Team ID (APPLE_TEAM_ID also works).
  DEVELOPER_ID_APPLICATION Developer ID Application identity (or --sign).

The script stages the Rust worker, builds the SwiftPM product, delegates CEF
framework/helper assembly to CefSwift, embeds the exact SwiftPM release resource
bundle and icon, signs the newly embedded artifacts, and runs the read-only
worker verifier. It never creates signing credentials and refuses ad-hoc or
unsigned artifacts. This is a release assembly scaffold: notarization still
requires the final hardened-runtime/entitlements policy and a positive signed
fixture.
USAGE
}

fail() {
  printf 'build-hive-app: %s\n' "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      [[ $# -ge 2 ]] || { echo "--output requires a directory" >&2; exit 2; }
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --sign)
      [[ $# -ge 2 ]] || { echo "--sign requires an identity" >&2; exit 2; }
      SIGNING_IDENTITY="$2"
      shift 2
      ;;
    --allow-adhoc)
      ALLOW_ADHOC=1
      shift
      ;;
    --entitlements)
      [[ $# -ge 2 ]] || { echo "--entitlements requires a path" >&2; exit 2; }
      ENTITLEMENTS_PATH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[[ "$(uname -s)" == "Darwin" ]] || fail "macOS is required for CEF app assembly and codesigning"
command -v swift >/dev/null 2>&1 || fail "swift is required"
if [[ -n "$ENTITLEMENTS_PATH" ]]; then
  [[ -f "$ENTITLEMENTS_PATH" ]] || fail "entitlements file is missing: $ENTITLEMENTS_PATH"
  "$ROOT_DIR/scripts/verify-hive-entitlements.sh" "$ENTITLEMENTS_PATH"
fi
command -v cargo >/dev/null 2>&1 || fail "cargo is required to build the research worker"
command -v codesign >/dev/null 2>&1 || fail "codesign is required"
command -v ditto >/dev/null 2>&1 || fail "ditto is required"

if [[ "$ALLOW_ADHOC" -eq 1 ]]; then
  SIGNING_IDENTITY="-"
  TEAM_ID="0000000000"
  HIVE_WORKER_REQUIREMENT='anchor apple generic and certificate leaf[subject.OU] = "0000000000" and identifier "com.hive.browser.research-worker"'
  printf '%s\n' 'WARNING: --allow-adhoc is local development only; this artifact is not a release.' >&2
else
  [[ -n "$SIGNING_IDENTITY" && "$SIGNING_IDENTITY" != "-" ]] || \
    fail "a real Developer ID Application identity is required; set DEVELOPER_ID_APPLICATION or pass --sign"
  [[ -n "$TEAM_ID" && "$TEAM_ID" =~ ^[A-Z0-9]{10}$ && "$TEAM_ID" != "0000000000" ]] || \
    fail "HIVE_WORKER_TEAM_ID or APPLE_TEAM_ID must be a real ten-character Apple Team ID"
  [[ -n "${HIVE_WORKER_REQUIREMENT:-}" ]] || \
    fail "HIVE_WORKER_REQUIREMENT is required; refusing to build an unauthenticated release"
  [[ "$HIVE_WORKER_REQUIREMENT" != *'0000000000'* ]] || \
    fail "HIVE_WORKER_REQUIREMENT contains the local-only dummy Team ID"
fi

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
APP_PATH="$OUTPUT_DIR/$APP_NAME"

printf '%s\n' '==> Staging signed-worker release inputs'
if [[ "$ALLOW_ADHOC" -eq 1 ]]; then
  HIVE_WORKER_TEAM_ID="$TEAM_ID" \
    HIVE_WORKER_REQUIREMENT="$HIVE_WORKER_REQUIREMENT" \
    "$ROOT_DIR/scripts/build-research-worker.sh" --allow-adhoc
else
  HIVE_WORKER_TEAM_ID="$TEAM_ID" \
    HIVE_WORKER_REQUIREMENT="$HIVE_WORKER_REQUIREMENT" \
    "$ROOT_DIR/scripts/build-research-worker.sh"
fi

printf '%s\n' '==> Building Hive SwiftPM resources'
swift build --configuration debug --product "$PRODUCT"

printf '%s\n' '==> Bundling CEF framework and Chromium helper apps'
swift package \
  --allow-writing-to-package-directory \
  --allow-network-connections all \
  cef bundle \
  --product "$PRODUCT" \
  --configuration debug \
  --output "$OUTPUT_DIR" \
  --bundle-id com.hive.browser \
  --sign "$SIGNING_IDENTITY"

[[ -d "$APP_PATH" ]] || fail "CefSwift did not produce $APP_PATH"

BUILD_BIN_DIR="$(swift build --configuration debug --show-bin-path)"
RESOURCE_SOURCE="$BUILD_BIN_DIR/Hive_Hive.bundle"
[[ -d "$RESOURCE_SOURCE" ]] || fail "SwiftPM release resource bundle is missing: $RESOURCE_SOURCE"
RESOURCE_DEST="$APP_PATH/Contents/Resources/$(basename "$RESOURCE_SOURCE")"
[[ ! -e "$RESOURCE_DEST" ]] || fail "unexpected pre-existing resource bundle in generated app: $RESOURCE_DEST"

printf '%s\n' '==> Embedding SwiftPM resources and Hive icon'
mkdir -p "$APP_PATH/Contents/Resources"
ditto "$RESOURCE_SOURCE" "$RESOURCE_DEST"
ICON_SOURCE="$ROOT_DIR/Sources/Hive/Resources/AppIcon.icns"
[[ -f "$ICON_SOURCE" ]] || fail "Hive app icon is missing: $ICON_SOURCE"
ditto "$ICON_SOURCE" "$APP_PATH/Contents/Resources/AppIcon.icns"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon.icns' "$APP_PATH/Contents/Info.plist" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c 'Set :CFBundleIconFile AppIcon.icns' "$APP_PATH/Contents/Info.plist"
# Voice mode uses the system Speech and microphone APIs. Add both usage
# descriptions to the generated app rather than relying on a developer-only
# plist, so the release artifact requests permission with an honest explanation.
/usr/libexec/PlistBuddy -c 'Add :NSSpeechRecognitionUsageDescription string Hive uses speech recognition to turn your voice into a command.' "$APP_PATH/Contents/Info.plist" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c 'Set :NSSpeechRecognitionUsageDescription Hive uses speech recognition to turn your voice into a command.' "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :NSMicrophoneUsageDescription string Hive uses the microphone only while you hold the voice control to listen.' "$APP_PATH/Contents/Info.plist" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c 'Set :NSMicrophoneUsageDescription Hive uses the microphone only while you hold the voice control to listen.' "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist" | grep -Fxq 'com.hive.browser' || \
  fail 'generated app bundle identifier is not com.hive.browser'
/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP_PATH/Contents/Info.plist" | grep -Fxq '14.0' || \
  fail 'generated app minimum macOS version is not 14.0'

WORKER_PATH="$RESOURCE_DEST/Contents/Resources/ResearchWorker/hive-fetch-worker"
REQUIREMENT_PATH="$RESOURCE_DEST/Contents/Resources/ResearchWorker/hive-worker-requirement.txt"
[[ -x "$WORKER_PATH" ]] || fail "embedded research worker is missing or not executable"
[[ -f "$REQUIREMENT_PATH" ]] || fail "embedded worker requirement is missing"

printf '%s\n' '==> Staging adblock-ffi native engine'
ADBLOCK_DYLIB="$ROOT_DIR/native/adblock-ffi/target/release/libhive_adblock_ffi.dylib"
if [[ -f "$ADBLOCK_DYLIB" ]]; then
  ADBLOCK_DEST="$APP_PATH/Contents/Frameworks/libhive_adblock_ffi.dylib"
  ditto "$ADBLOCK_DYLIB" "$ADBLOCK_DEST"
  printf '  adblock engine staged: %s\n' "$ADBLOCK_DEST"
else
  printf '  adblock dylib not found at %s — building now...\n' "$ADBLOCK_DYLIB"
  (cd "$ROOT_DIR/native/adblock-ffi" && cargo build --release) || fail 'adblock-ffi cargo build failed'
  ditto "$ADBLOCK_DYLIB" "$APP_PATH/Contents/Frameworks/libhive_adblock_ffi.dylib"
  printf '  adblock engine built and staged\n'
fi

printf '%s\n' '==> Signing embedded worker, CEF nested code, SwiftPM resources, and outer app'
sign_path() {
  local path="$1"
  shift
  if [[ -n "$ENTITLEMENTS_PATH" ]]; then
    codesign --force --timestamp --options runtime --entitlements "$ENTITLEMENTS_PATH" "$@" "$path"
  else
    codesign --force --timestamp=none "$@" "$path"
  fi
}

sign_plain_path() {
  local path="$1"
  shift
  if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    codesign --force --timestamp=none "$@" "$path"
  else
    codesign --force --timestamp "$@" "$path"
  fi
}

# CefSwift signs the initial bundle. Re-sign every nested executable inside-out
# when a release entitlements policy is supplied, then seal the outer app last.
CEF_FRAMEWORK="$APP_PATH/Contents/Frameworks/Chromium Embedded Framework.framework"
if [[ -d "$CEF_FRAMEWORK/Libraries" ]]; then
  while IFS= read -r -d '' library; do
    sign_path "$library" --sign "$SIGNING_IDENTITY"
  done < <(find "$CEF_FRAMEWORK/Libraries" \( -type f -o -type l \) -name '*.dylib' -print0 2>/dev/null)
fi
sign_path "$CEF_FRAMEWORK/Chromium Embedded Framework" --sign "$SIGNING_IDENTITY"
sign_path "$CEF_FRAMEWORK" --sign "$SIGNING_IDENTITY"
for helper in \
  "Hive Helper.app" \
  "Hive Helper (Alerts).app" \
  "Hive Helper (GPU).app" \
  "Hive Helper (Plugin).app" \
  "Hive Helper (Renderer).app"; do
  helper_path="$APP_PATH/Contents/Frameworks/$helper"
  helper_executable="${helper%.app}"
  sign_path "$helper_path/Contents/MacOS/$helper_executable" --sign "$SIGNING_IDENTITY"
  sign_path "$helper_path" --sign "$SIGNING_IDENTITY"
done
# The worker and resource bundle do not need CEF's JIT/library-validation
# exceptions; keep their signatures least-privilege.
sign_plain_path "$WORKER_PATH" --identifier com.hive.browser.research-worker --sign "$SIGNING_IDENTITY"
# Adblock engine — same least-privilege signature as the worker
ADBLOCK_DYLIB_DEST="$APP_PATH/Contents/Frameworks/libhive_adblock_ffi.dylib"
if [[ -f "$ADBLOCK_DYLIB_DEST" ]]; then
  sign_plain_path "$ADBLOCK_DYLIB_DEST" --identifier com.hive.browser.adblock --sign "$SIGNING_IDENTITY"
fi
sign_plain_path "$RESOURCE_DEST" --sign "$SIGNING_IDENTITY"
sign_path "$APP_PATH/Contents/MacOS/Hive" --sign "$SIGNING_IDENTITY"
sign_path "$APP_PATH" --sign "$SIGNING_IDENTITY"

printf '%s\n' '==> Running Hive structural release preflight'
if [[ "$ALLOW_ADHOC" -eq 1 ]]; then
  "$ROOT_DIR/scripts/preflight-hive-app.sh" --app "$APP_PATH" --allow-adhoc
else
  "$ROOT_DIR/scripts/preflight-hive-app.sh" --app "$APP_PATH"
fi

if [[ "$ALLOW_ADHOC" -eq 1 ]]; then
  printf '%s\n' '==> Skipping release-only worker requirement verification (local ad-hoc mode)'
else
  printf '%s\n' '==> Verifying signed Hive worker release contract'
  HIVE_WORKER_TEAM_ID="$TEAM_ID" \
    "$ROOT_DIR/scripts/verify-research-worker.sh" \
    --app "$APP_PATH" \
    --team-id "$TEAM_ID"
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist" | grep -Fxq 'com.hive.browser'
/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP_PATH/Contents/Info.plist" | grep -Fxq '14.0'

if [[ "$ALLOW_ADHOC" -eq 1 ]]; then
  printf 'Built local ad-hoc Hive app: %s\n' "$APP_PATH"
  printf '%s\n' 'This artifact is not signed for distribution, cannot satisfy the release worker requirement, and must not be notarized.'
else
  printf 'Built signed Hive app: %s\n' "$APP_PATH"
    printf '%s\n' '==> Creating signed .dmg for distribution'
  DMG_PATH="$OUTPUT_DIR/Hive.dmg"
  TMP_DMG="$OUTPUT_DIR/.Hive-tmp.dmg"
  rm -f "$DMG_PATH" "$TMP_DMG"
  hdiutil create -volname Hive -srcfolder "$APP_PATH" -ov -format UDZO "$TMP_DMG" >/dev/null || fail 'hdiutil create failed'
  # Sign the .dmg with the Developer ID identity
  if [[ "$SIGNING_IDENTITY" != "-" ]]; then
    codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$TMP_DMG" || fail 'codesign on .dmg failed'
  fi
  mv "$TMP_DMG" "$DMG_PATH"
  printf 'Signed .dmg: %s\n' "$DMG_PATH"

  printf '%s\n' '==> Notarizing and stapling release .dmg'
  APPLE_ID="${APPLE_ID:-}" \
  APPLE_APP_PASSWORD="${APPLE_APP_PASSWORD:-}" \
  APPLE_TEAM_ID="$TEAM_ID" \
    "$ROOT_DIR/scripts/notarize-hive-app.sh" "$DMG_PATH"
fi