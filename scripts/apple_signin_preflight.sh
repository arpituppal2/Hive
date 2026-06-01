#!/usr/bin/env bash
set -euo pipefail

APP="${HIVE_APP_DIR:-"$HOME/Applications/Hive.app"}"
EXPECTED_BUNDLE_IDENTIFIER="${HIVE_BUNDLE_IDENTIFIER:-}"
EXPECTED_DEVELOPMENT_TEAM="${HIVE_DEVELOPMENT_TEAM:-}"

fail() {
  echo "Hive Sign in with Apple preflight failed: $*" >&2
  exit 1
}

if [[ ! -d "$APP" ]]; then
  fail "app bundle not found at $APP"
fi

IDENTITIES="$(security find-identity -v -p codesigning 2>/dev/null || true)"
if ! grep -Eq 'Apple Development|Developer ID Application' <<<"$IDENTITIES"; then
  fail "no Apple Development or Developer ID Application signing identity is installed in this keychain"
fi

SIGNING_DETAILS="$(codesign -dv --verbose=4 "$APP" 2>&1 || true)"
if ! grep -q 'TeamIdentifier=' <<<"$SIGNING_DETAILS"; then
  fail "installed app is not Apple-signed with a TeamIdentifier"
fi
if grep -q 'TeamIdentifier=not set' <<<"$SIGNING_DETAILS"; then
  fail "installed app is ad-hoc signed; TeamIdentifier is not set"
fi
if [[ -n "$EXPECTED_DEVELOPMENT_TEAM" ]] && ! grep -q "TeamIdentifier=${EXPECTED_DEVELOPMENT_TEAM}" <<<"$SIGNING_DETAILS"; then
  fail "installed app TeamIdentifier does not match HIVE_DEVELOPMENT_TEAM"
fi

if [[ -n "$EXPECTED_BUNDLE_IDENTIFIER" ]]; then
  ACTUAL_BUNDLE_IDENTIFIER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist" 2>/dev/null || true)"
  [[ "$ACTUAL_BUNDLE_IDENTIFIER" == "$EXPECTED_BUNDLE_IDENTIFIER" ]] || fail "installed app bundle identifier does not match HIVE_BUNDLE_IDENTIFIER"
fi

ENTITLEMENTS="$(codesign -d --entitlements :- "$APP" 2>/dev/null || true)"
if ! grep -q 'com.apple.developer.applesignin' <<<"$ENTITLEMENTS"; then
  fail "installed app is missing com.apple.developer.applesignin"
fi

if ! codesign --verify --deep --strict --verbose=2 "$APP" >/dev/null; then
  fail "installed app code signature does not verify"
fi

echo "Hive Sign in with Apple preflight passed: $APP"
