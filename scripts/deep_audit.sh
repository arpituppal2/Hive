#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_SUPPORT="${HIVE_APP_SUPPORT:-$HOME/Library/Application Support/Hive}"
DEFAULTS_DOMAIN="${HIVE_DEFAULTS_DOMAIN:-local.hive.desktop}"
BACKUP_ROOT="${HIVE_AUDIT_BACKUP_ROOT:-$HOME/Desktop/Hive Audit Backups}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/$STAMP"
REAL_DESTRUCTIVE=0

for arg in "$@"; do
  case "$arg" in
    --real-destructive)
      REAL_DESTRUCTIVE=1
      ;;
    --help|-h)
      cat <<'USAGE'
Usage: scripts/deep_audit.sh [--real-destructive]

Runs Hive's deep verification harness. By default this is non-destructive:
it backs up user state, runs tests, and builds the app.

--real-destructive also requires HIVE_REAL_DESTRUCTIVE_AUDIT=1. This guard
exists so deleting sources, logging out, and reset-style flows cannot run by
accident from a normal shell or CI job.
USAGE
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

if [[ "$REAL_DESTRUCTIVE" == "1" && "${HIVE_REAL_DESTRUCTIVE_AUDIT:-0}" != "1" ]]; then
  echo "Refusing real destructive audit without HIVE_REAL_DESTRUCTIVE_AUDIT=1." >&2
  exit 3
fi

mkdir -p "$BACKUP_DIR"
if [[ -d "$APP_SUPPORT" ]]; then
  ditto "$APP_SUPPORT" "$BACKUP_DIR/Application Support Hive"
fi
defaults export "$DEFAULTS_DOMAIN" "$BACKUP_DIR/defaults.plist" >/dev/null 2>&1 || true

echo "Hive audit backup: $BACKUP_DIR"
cd "$ROOT"

run_swift_suite() {
  local suite_name="$1"
  local log_file
  log_file="$(mktemp "/tmp/hive-${suite_name}.log.XXXXXX")"
  echo "Running Swift tests: $suite_name..."
  HIVE_DISABLE_LIVE_PERSONAL_CONTEXT=1 swift test --filter "$suite_name" 2>&1 | tee "$log_file"
  if grep -E "CoreData|AddressBook|NSXPC|Unable to connect to server" "$log_file" >/dev/null; then
    echo "Swift test log for $suite_name contained personal-data or system-store access noise: $log_file" >&2
    exit 4
  fi
}

run_swift_suite "HiveCoreTests"
run_swift_suite "HiveRebuildTests"

echo "Running Apple HIG static audit..."
python3 scripts/apple_hig_static_audit.py

if [[ "${HIVE_AUDIT_SKIP_BUILD:-0}" != "1" && -x scripts/build_app.sh ]]; then
  echo "Building app..."
  if [[ -n "${HIVE_BUNDLE_IDENTIFIER:-}" && -n "${HIVE_DEVELOPMENT_TEAM:-}" && -n "${HIVE_CODESIGN_IDENTITY:-}" ]]; then
    scripts/build_app.sh
  else
    HIVE_ALLOW_UNSIGNED_LOCKED_BUILD=1 scripts/build_app.sh
  fi
fi

if [[ "$REAL_DESTRUCTIVE" == "1" ]]; then
  cat <<'NOTICE'
Real destructive audit is enabled. The app-state backup above is the restore
point for logout, raw-source removal, article deletion, and reset-style checks.
No additional destructive UI automation is embedded here; run it deliberately
from the audited app build so failures remain observable.
NOTICE
fi
