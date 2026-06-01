#!/usr/bin/env bash
set -euo pipefail

APP="${HIVE_APP_DIR:-"$HOME/Applications/Hive.app"}"
EXPECTED_CLIENT_ID="${HIVE_GOOGLE_CLIENT_ID:-}"
EXPECTED_REVERSED_CLIENT_ID="${HIVE_GOOGLE_REVERSED_CLIENT_ID:-}"

fail() {
  echo "Hive Sign in with Google preflight failed: $*" >&2
  exit 1
}

if [[ ! -d "$APP" ]]; then
  fail "app bundle not found at $APP"
fi
if [[ -z "$EXPECTED_CLIENT_ID" || -z "$EXPECTED_REVERSED_CLIENT_ID" ]]; then
  fail "set HIVE_GOOGLE_CLIENT_ID and HIVE_GOOGLE_REVERSED_CLIENT_ID before running this check"
fi

python3 - "$APP/Contents/Info.plist" "$EXPECTED_CLIENT_ID" "$EXPECTED_REVERSED_CLIENT_ID" <<'PY'
import plistlib
import sys

path, expected_client_id, expected_callback_scheme = sys.argv[1:4]
with open(path, "rb") as file:
    info = plistlib.load(file)

def fail(message):
    raise SystemExit(message)

if info.get("GIDClientID") != expected_client_id:
    fail("installed app GIDClientID does not match HIVE_GOOGLE_CLIENT_ID")
if info.get("HiveGoogleReversedClientID") != expected_callback_scheme:
    fail("installed app HiveGoogleReversedClientID does not match HIVE_GOOGLE_REVERSED_CLIENT_ID")

schemes = [
    scheme
    for url_type in info.get("CFBundleURLTypes", [])
    for scheme in url_type.get("CFBundleURLSchemes", [])
]
if expected_callback_scheme not in schemes:
    fail("installed app is missing the Google callback URL scheme")
PY

if ! codesign --verify --deep --strict --verbose=2 "$APP" >/dev/null; then
  fail "installed app code signature does not verify"
fi

echo "Hive Sign in with Google preflight passed: $APP"
