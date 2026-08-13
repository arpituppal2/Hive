#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/Hive.app"
ALLOW_ADHOC=0

usage() {
  cat <<'USAGE'
Audit a Hive.app bundle without modifying it.

Usage:
  scripts/preflight-hive-app.sh [--app PATH] [--allow-adhoc]

Options:
  --app PATH       Bundle to inspect (default: ./dist/Hive.app).
  --allow-adhoc    Permit an ad-hoc signature for local development only.
  -h, --help       Show this help.

The default mode is a release gate: the app, CEF framework, helpers, and
SwiftPM resource bundle must have valid signatures and the outer app must have
a real TeamIdentifier. This script never signs, notarizes, modifies, or prints
worker requirement contents. It does not claim notarization; use the verifier
and stapler checks for that.
USAGE
}

fail() {
  printf 'preflight-hive-app: %s\n' "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      [[ $# -ge 2 ]] || { echo "--app requires a path" >&2; exit 2; }
      APP_PATH="$2"
      shift 2
      ;;
    --allow-adhoc)
      ALLOW_ADHOC=1
      shift
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

[[ "$(uname -s)" == "Darwin" ]] || fail "macOS is required"
command -v codesign >/dev/null 2>&1 || fail "codesign is required"
command -v find >/dev/null 2>&1 || fail "find is required"
[[ -x /usr/libexec/PlistBuddy ]] || fail "PlistBuddy is required"

[[ -d "$APP_PATH" && "$APP_PATH" == *.app ]] || fail "not an app bundle: $APP_PATH"
APP_PATH="$(cd "$APP_PATH" && pwd)"
CONTENTS="$APP_PATH/Contents"
RESOURCES="$CONTENTS/Resources"
FRAMEWORKS="$CONTENTS/Frameworks"
MAIN_EXECUTABLE="$CONTENTS/MacOS/Hive"

[[ -f "$CONTENTS/Info.plist" ]] || fail "missing Contents/Info.plist"
[[ -x "$MAIN_EXECUTABLE" ]] || fail "missing or non-executable Hive binary"
[[ -d "$RESOURCES" ]] || fail "missing Contents/Resources"
[[ -d "$FRAMEWORKS" ]] || fail "missing Contents/Frameworks"

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null
}

[[ "$(plist_value "$CONTENTS/Info.plist" CFBundleIdentifier)" == "com.hive.browser" ]] || \
  fail "CFBundleIdentifier is not com.hive.browser"
[[ "$(plist_value "$CONTENTS/Info.plist" CFBundleExecutable)" == "Hive" ]] || \
  fail "CFBundleExecutable is not Hive"
[[ "$(plist_value "$CONTENTS/Info.plist" LSMinimumSystemVersion)" == "14.0" ]] || \
  fail "LSMinimumSystemVersion is not 14.0"

CEF_FRAMEWORK="$FRAMEWORKS/Chromium Embedded Framework.framework"
[[ -d "$CEF_FRAMEWORK" ]] || fail "missing Chromium Embedded Framework.framework"
[[ -f "$CEF_FRAMEWORK/Chromium Embedded Framework" || -L "$CEF_FRAMEWORK/Chromium Embedded Framework" ]] || \
  fail "CEF framework binary is missing"

CEF_LIBRARIES=()
if [[ -d "$CEF_FRAMEWORK/Libraries" ]]; then
  while IFS= read -r -d '' library; do
    [[ -n "$library" ]] && CEF_LIBRARIES[${#CEF_LIBRARIES[@]}]="$library"
  done < <(find "$CEF_FRAMEWORK/Libraries" \( -type f -o -type l \) -name '*.dylib' -print0 2>/dev/null)
fi

HELPERS=(
  "Hive Helper.app"
  "Hive Helper (Alerts).app"
  "Hive Helper (GPU).app"
  "Hive Helper (Plugin).app"
  "Hive Helper (Renderer).app"
)
for helper in "${HELPERS[@]}"; do
  helper_path="$FRAMEWORKS/$helper"
  [[ -d "$helper_path" ]] || fail "missing CEF helper: $helper"
  helper_executable_name="${helper%.app}"
  helper_executable="$helper_path/Contents/MacOS/$helper_executable_name"
  [[ -x "$helper_executable" ]] || fail "missing helper executable: $helper_executable_name"
  helper_id="$(plist_value "$helper_path/Contents/Info.plist" CFBundleIdentifier)"
  [[ "$helper_id" == com.hive.browser.helper* ]] || fail "unexpected helper identifier for $helper: $helper_id"
done

# The pinned CefSwift layout is intentionally explicit. If a dependency update
# introduces another nested app/framework, fail before signing/notarization
# rather than silently leaving new code outside the signing contract.
EXPECTED_NESTED_BUNDLES=(
  "$CEF_FRAMEWORK"
  "$FRAMEWORKS/Sparkle.framework"
  "$FRAMEWORKS/Sparkle.framework/Versions/B/Updater.app"
  "$FRAMEWORKS/Hive Helper.app"
  "$FRAMEWORKS/Hive Helper (Alerts).app"
  "$FRAMEWORKS/Hive Helper (GPU).app"
  "$FRAMEWORKS/Hive Helper (Plugin).app"
  "$FRAMEWORKS/Hive Helper (Renderer).app"
)
for expected_bundle in "${EXPECTED_NESTED_BUNDLES[@]}"; do
  [[ -d "$expected_bundle" ]] || fail "missing expected nested bundle: $expected_bundle"
done
while IFS= read -r -d '' nested_bundle; do
  expected=0
  for expected_bundle in "${EXPECTED_NESTED_BUNDLES[@]}"; do
    if [[ "$nested_bundle" == "$expected_bundle" ]]; then
      expected=1
      break
    fi
  done
  [[ "$expected" -eq 1 ]] || \
    fail "unexpected nested CEF bundle; inspect and update the signing contract: $nested_bundle"
done < <(find "$FRAMEWORKS" -type d \( -name '*.app' -o -name '*.framework' \) -print0 2>/dev/null)

bundle_candidates=()
while IFS= read -r -d '' candidate; do
  [[ -n "$candidate" ]] && bundle_candidates[${#bundle_candidates[@]}]="$candidate"
done < <(find "$RESOURCES" -type d -name '*_Hive.bundle' -path '*/Contents/Resources/*_Hive.bundle' -print0)
[[ "${#bundle_candidates[@]}" -eq 1 ]] || fail "expected exactly one Hive SwiftPM resource bundle"
RESOURCE_BUNDLE="${bundle_candidates[0]}"
WORKER="$RESOURCE_BUNDLE/Contents/Resources/ResearchWorker/hive-fetch-worker"
REQUIREMENT="$RESOURCE_BUNDLE/Contents/Resources/ResearchWorker/hive-worker-requirement.txt"
SPARKLE_UPDATER="$FRAMEWORKS/Sparkle.framework/Versions/B/Updater.app/Contents/MacOS/Updater"
[[ -x "$WORKER" ]] || fail "missing or non-executable embedded research worker"
[[ -f "$REQUIREMENT" ]] || fail "missing embedded worker requirement"
[[ -x "$SPARKLE_UPDATER" ]] || fail "missing or non-executable Sparkle updater"

# Adblock native engine (optional — warn if missing, don't fail)
ADBLOCK_DYLIB="$FRAMEWORKS/libhive_adblock_ffi.dylib"
if [[ -f "$ADBLOCK_DYLIB" ]]; then
  printf '  adblock engine: present
'
  codesign --verify --strict "$ADBLOCK_DYLIB" >/dev/null 2>&1 || printf '  WARNING: adblock dylib signature invalid
'
else
  printf '  WARNING: adblock engine not staged — falling back to EasyList
'
fi

verify_signature() {
  local path="$1"
  codesign --verify --strict "$path" >/dev/null 2>&1 || fail "invalid signature: $path"
}

signature_team_identifier() {
  local path="$1"
  local metadata
  metadata="$(codesign -dvvv "$path" 2>&1)" || fail "could not inspect signature: $path"
  printf '%s\n' "$metadata" | sed -n 's/^TeamIdentifier=//p' | head -1
}

verify_signature "$CEF_FRAMEWORK"
verify_signature "$CEF_FRAMEWORK/Chromium Embedded Framework"
verify_signature "$FRAMEWORKS/Sparkle.framework"
verify_signature "$FRAMEWORKS/Sparkle.framework/Versions/B/Updater.app"
verify_signature "$SPARKLE_UPDATER"
if [[ "${#CEF_LIBRARIES[@]}" -gt 0 ]]; then
  for library in "${CEF_LIBRARIES[@]}"; do
    verify_signature "$library"
  done
fi
for helper in "${HELPERS[@]}"; do
  helper_path="$FRAMEWORKS/$helper"
  verify_signature "$helper_path"
  helper_executable_name="${helper%.app}"
  verify_signature "$helper_path/Contents/MacOS/$helper_executable_name"
done
verify_signature "$RESOURCE_BUNDLE"
verify_signature "$WORKER"
verify_signature "$MAIN_EXECUTABLE"
verify_signature "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH" >/dev/null 2>&1 || fail "deep app signature verification failed"

metadata="$(codesign -dvvv "$APP_PATH" 2>&1)" || fail "could not inspect app signature"
signature_kind="$(printf '%s\n' "$metadata" | sed -n 's/^Signature=//p' | head -1)"
team_identifier="$(printf '%s\n' "$metadata" | sed -n 's/^TeamIdentifier=//p' | head -1)"
if [[ "$signature_kind" == "adhoc" || -z "$team_identifier" || "$team_identifier" == "not set" ]]; then
  if [[ "$ALLOW_ADHOC" -eq 1 ]]; then
    printf '%s\n' 'Signature state: ad-hoc (allowed only for local development)'
    assert_adhoc_signature() {
      local path="$1"
      local nested_metadata
      nested_metadata="$(codesign -dvvv "$path" 2>&1)" || fail "could not inspect local signature: $path"
      local nested_signature
      nested_signature="$(printf '%s\n' "$nested_metadata" | sed -n 's/^Signature=//p' | head -1)"
      local nested_team
      nested_team="$(printf '%s\n' "$nested_metadata" | sed -n 's/^TeamIdentifier=//p' | head -1)"
      [[ "$nested_signature" == "adhoc" && ( -z "$nested_team" || "$nested_team" == "not set" ) ]] || \
        fail "local ad-hoc bundle contains a non-ad-hoc signature: $path"
    }
    assert_adhoc_signature "$CEF_FRAMEWORK"
    assert_adhoc_signature "$CEF_FRAMEWORK/Chromium Embedded Framework"
    assert_adhoc_signature "$FRAMEWORKS/Sparkle.framework"
    assert_adhoc_signature "$FRAMEWORKS/Sparkle.framework/Versions/B/Updater.app"
    assert_adhoc_signature "$SPARKLE_UPDATER"
    if [[ "${#CEF_LIBRARIES[@]}" -gt 0 ]]; then
      for library in "${CEF_LIBRARIES[@]}"; do
        assert_adhoc_signature "$library"
      done
    fi
    for helper in "${HELPERS[@]}"; do
      helper_path="$FRAMEWORKS/$helper"
      helper_executable_name="${helper%.app}"
      assert_adhoc_signature "$helper_path"
      assert_adhoc_signature "$helper_path/Contents/MacOS/$helper_executable_name"
    done
    assert_adhoc_signature "$RESOURCE_BUNDLE"
    assert_adhoc_signature "$WORKER"
    assert_adhoc_signature "$MAIN_EXECUTABLE"
    assert_adhoc_signature "$APP_PATH"
  else
    fail "app is ad-hoc signed or has no TeamIdentifier; pass --allow-adhoc only for local development"
  fi
else
  printf 'Signature Team ID: %s\n' "$team_identifier"
  for signed_path in "$CEF_FRAMEWORK" "$CEF_FRAMEWORK/Chromium Embedded Framework" "$FRAMEWORKS/Sparkle.framework" "$FRAMEWORKS/Sparkle.framework/Versions/B/Updater.app" "$SPARKLE_UPDATER" "$WORKER" "$RESOURCE_BUNDLE" "$MAIN_EXECUTABLE" "$APP_PATH"; do
    nested_team="$(signature_team_identifier "$signed_path")"
    [[ "$nested_team" == "$team_identifier" ]] || \
      fail "nested signature TeamIdentifier mismatch: $signed_path"
  done
  if [[ "${#CEF_LIBRARIES[@]}" -gt 0 ]]; then
    for library in "${CEF_LIBRARIES[@]}"; do
      nested_team="$(signature_team_identifier "$library")"
      [[ "$nested_team" == "$team_identifier" ]] || \
        fail "CEF library TeamIdentifier mismatch: $library"
    done
  fi
  for helper in "${HELPERS[@]}"; do
    helper_path="$FRAMEWORKS/$helper"
    nested_team="$(signature_team_identifier "$helper_path")"
    [[ "$nested_team" == "$team_identifier" ]] || \
      fail "helper signature TeamIdentifier mismatch: $helper"
    helper_executable_name="${helper%.app}"
    nested_team="$(signature_team_identifier "$helper_path/Contents/MacOS/$helper_executable_name")"
    [[ "$nested_team" == "$team_identifier" ]] || \
      fail "helper executable TeamIdentifier mismatch: $helper_executable_name"
  done
fi

printf 'Preflight passed: %s\n' "$APP_PATH"
printf 'CEF helpers: %s\n' "${#HELPERS[@]}"
printf 'SwiftPM resource bundle: %s\n' "$(basename "$RESOURCE_BUNDLE")"
printf '%s\n' 'Notarization: not checked'