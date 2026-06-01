#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${HIVE_APP_DIR:-"$HOME/Applications/Hive.app"}"
HELPER="$APP/Contents/Library/Helpers/HiveDaemon"

cd "$ROOT"

run_swift_suite() {
  local suite_name="$1"
  local log_file
  log_file="$(mktemp "/tmp/hive-acceptance-${suite_name}.log.XXXXXX")"
  HIVE_DISABLE_LIVE_PERSONAL_CONTEXT=1 swift test --filter "$suite_name" 2>&1 | tee "$log_file"
  if grep -E "CoreData|AddressBook|NSXPC|Unable to connect to server" "$log_file" >/dev/null; then
    echo "Acceptance test log for $suite_name contained personal-data or system-store access noise: $log_file" >&2
    exit 4
  fi
}

run_swift_suite "HiveCoreTests"
run_swift_suite "HiveRebuildTests"

if [[ -n "${HIVE_BUNDLE_IDENTIFIER:-}" && -n "${HIVE_DEVELOPMENT_TEAM:-}" && -n "${HIVE_CODESIGN_IDENTITY:-}" ]]; then
  scripts/build_app.sh release
  scripts/apple_signin_preflight.sh
  if [[ -n "${HIVE_GOOGLE_CLIENT_ID:-}" || -n "${HIVE_GOOGLE_REVERSED_CLIENT_ID:-}" ]]; then
    scripts/google_signin_preflight.sh
  fi
else
  HIVE_ALLOW_UNSIGNED_LOCKED_BUILD=1 scripts/build_app.sh release
  echo "Skipping production Sign in with Apple preflight for unsigned diagnostic acceptance build."
fi
codesign --verify --deep --strict --verbose=2 "$APP"
plutil -lint "$APP/Contents/Info.plist"
bash -n scripts/apple_signin_preflight.sh scripts/google_signin_preflight.sh scripts/install_launch_agent.sh scripts/uninstall_launch_agent.sh
"$HELPER" --manual

echo "Hive acceptance passed: $APP"
