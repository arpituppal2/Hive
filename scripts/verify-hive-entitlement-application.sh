#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${ROOT_DIR}/dist/Hive.app"

fail() {
  printf 'verify-hive-entitlement-application: %s\n' "$1" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Audit entitlements embedded in a signed Hive.app.

Usage:
  scripts/verify-hive-entitlement-application.sh [--app PATH]

The CEF framework, helpers, main executable, and outer app must carry exactly
Hive.entitlements. The Rust research worker and SwiftPM resource bundle
must carry no entitlements. This is a read-only audit and does not sign or
modify the app.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      [[ $# -ge 2 ]] || { echo "--app requires a path" >&2; exit 2; }
      APP_PATH="$2"
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

[[ "$(uname -s)" == "Darwin" ]] || fail "macOS is required"
command -v codesign >/dev/null 2>&1 || fail "codesign is required"
command -v plutil >/dev/null 2>&1 || fail "plutil is required"
[[ -x /usr/libexec/PlistBuddy ]] || fail "PlistBuddy is required"
[[ -d "$APP_PATH" && "$APP_PATH" == *.app ]] || fail "not an app bundle: $APP_PATH"
APP_PATH="$(cd "$APP_PATH" && pwd)"

FRAMEWORKS="$APP_PATH/Contents/Frameworks"
CEF_FRAMEWORK="$FRAMEWORKS/Chromium Embedded Framework.framework"
MAIN_EXECUTABLE="$APP_PATH/Contents/MacOS/Hive"
[[ -d "$CEF_FRAMEWORK" ]] || fail "missing CEF framework"
[[ -x "$MAIN_EXECUTABLE" ]] || fail "missing main executable"

HELPERS=(
  "Hive Helper.app"
  "Hive Helper (Alerts).app"
  "Hive Helper (GPU).app"
  "Hive Helper (Plugin).app"
  "Hive Helper (Renderer).app"
)

CEF_PATHS=("$APP_PATH" "$MAIN_EXECUTABLE" "$CEF_FRAMEWORK" "$CEF_FRAMEWORK/Chromium Embedded Framework")
if [[ -d "$CEF_FRAMEWORK/Libraries" ]]; then
  while IFS= read -r -d '' library; do
    CEF_PATHS[${#CEF_PATHS[@]}]="$library"
  done < <(find "$CEF_FRAMEWORK/Libraries" \( -type f -o -type l \) -name '*.dylib' -print0 2>/dev/null)
fi
for helper in "${HELPERS[@]}"; do
  helper_path="$FRAMEWORKS/$helper"
  helper_executable="${helper%.app}"
  [[ -d "$helper_path" ]] || fail "missing helper: $helper"
  [[ -x "$helper_path/Contents/MacOS/$helper_executable" ]] || fail "missing helper executable: $helper_executable"
  CEF_PATHS[${#CEF_PATHS[@]}]="$helper_path"
  CEF_PATHS[${#CEF_PATHS[@]}]="$helper_path/Contents/MacOS/$helper_executable"
done

RESOURCE_BUNDLE=""
while IFS= read -r -d '' candidate; do
  [[ -z "$RESOURCE_BUNDLE" ]] || fail "multiple Hive resource bundles found"
  RESOURCE_BUNDLE="$candidate"
done < <(find "$APP_PATH/Contents/Resources" -type d -name '*_Hive.bundle' -path '*/Contents/Resources/*_Hive.bundle' -print0 2>/dev/null)
[[ -n "$RESOURCE_BUNDLE" ]] || fail "Hive resource bundle is missing"
WORKER="$RESOURCE_BUNDLE/Contents/Resources/ResearchWorker/hive-fetch-worker"
[[ -x "$WORKER" ]] || fail "research worker is missing"

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hive-entitlement-audit.XXXXXX")"
cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

require_policy() {
  local path="$1"
  local name="$2"
  local plist
  plist="$(mktemp "$TEMP_DIR/policy.XXXXXX")"
  codesign -d --entitlements :- "$path" > "$plist" 2>/dev/null || fail "could not read entitlements: $name"
  [[ -s "$plist" ]] || fail "CEF/app path has no entitlements: $name"
  "$ROOT_DIR/scripts/verify-hive-entitlements.sh" "$plist" >/dev/null || \
    fail "unexpected CEF/app entitlements: $name"
}

require_plain() {
  local path="$1"
  local name="$2"
  local plist
  plist="$(mktemp "$TEMP_DIR/plain.XXXXXX")"
  codesign -d --entitlements :- "$path" > "$plist" 2>/dev/null || fail "could not read entitlements: $name"
  [[ -s "$plist" ]] || fail "could not read entitlements: $name"
  plutil -lint "$plist" >/dev/null 2>&1 || fail "unparseable entitlements on plain path: $name"
  local entitlement_json
  entitlement_json="$(plutil -convert json -o - "$plist" 2>/dev/null | tr -d '[:space:]')" || fail "could not parse entitlements: $name"
  [[ "$entitlement_json" == "{}" ]] || \
    fail "plain path unexpectedly carries entitlements: $name"
}

for path in "${CEF_PATHS[@]}"; do
  require_policy "$path" "$path"
done
require_plain "$RESOURCE_BUNDLE" "$RESOURCE_BUNDLE"
require_plain "$WORKER" "$WORKER"

printf 'Signed entitlement separation passed: %s\n' "$APP_PATH"
printf 'CEF/app paths with reviewed policy: %s\n' "${#CEF_PATHS[@]}"
printf '%s\n' 'Worker/resource paths with no entitlements: 2'
