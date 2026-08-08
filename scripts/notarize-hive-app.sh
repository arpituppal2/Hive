#!/usr/bin/env bash
set -euo pipefail

# notarize-hive-app.sh
# Submit a signed Hive .dmg to Apple for notarization, wait for approval,
# and staple the ticket. Requires Apple Developer credentials.

DMG_PATH="${1:-}"
APPLE_ID="${APPLE_ID:-}"
APPLE_APP_PASSWORD="${APPLE_APP_PASSWORD:-}"
TEAM_ID="${APPLE_TEAM_ID:-}"

usage() {
  cat <<'USAGE'
Notarize and staple a signed Hive .dmg.

Usage:
  scripts/notarize-hive-app.sh <path-to-signed.dmg>

Required environment variables:
  APPLE_ID           Apple ID email address
  APPLE_APP_PASSWORD App-specific password for notarization
  APPLE_TEAM_ID      Ten-character Apple Team ID

The .dmg must already be signed with a Developer ID Application certificate
and include hardened runtime entitlements. This script only handles the
notarization submission, polling, and stapling steps.
USAGE
}

fail() {
  printf 'notarize-hive-app: %s\n' "$1" >&2
  exit 1
}

[[ -n "$DMG_PATH" ]] || { usage >&2; fail "missing .dmg path argument"; }
[[ -f "$DMG_PATH" ]] || fail ".dmg not found: $DMG_PATH"
[[ "$DMG_PATH" == *.dmg ]] || fail "must be a .dmg file: $DMG_PATH"

[[ -n "$APPLE_ID" ]] || fail "APPLE_ID is required"
[[ -n "$APPLE_APP_PASSWORD" ]] || fail "APPLE_APP_PASSWORD is required"
[[ -n "$TEAM_ID" && "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || fail "APPLE_TEAM_ID must be a ten-character Apple Team ID"

command -v xcrun >/dev/null 2>&1 || fail "xcrun is required"
command -v stapler >/dev/null 2>&1 || fail "stapler is required"

printf '%s\n' '==> Submitting for notarization...'

SUBMIT_OUTPUT="$(xcrun notarytool submit "$DMG_PATH" \
  --apple-id "$APPLE_ID" \
  --password "$APPLE_APP_PASSWORD" \
  --team-id "$TEAM_ID" \
  --wait \
  --timeout 15m \
  2>&1)"

SUBMIT_EXIT=$?

printf '%s\n' "$SUBMIT_OUTPUT"

if [[ $SUBMIT_EXIT -ne 0 ]]; then
  fail "notarytool submit failed with exit code $SUBMIT_EXIT"
fi

# Extract submission ID for history lookup
SUBMISSION_ID="$(echo "$SUBMIT_OUTPUT" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)"

if [[ -n "$SUBMISSION_ID" ]]; then
  printf 'Submission ID: %s\n' "$SUBMISSION_ID"

  LOG_OUTPUT="$(xcrun notarytool log "$SUBMISSION_ID" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --team-id "$TEAM_ID" \
    2>&1)" || true
  printf '%s\n' "$LOG_OUTPUT"
fi

# Verify notarization status
STATUS="$(echo "$SUBMIT_OUTPUT" | grep -i 'status:' | awk '{print $NF}' | tr '[:upper:]' '[:lower:]')"

if [[ "$STATUS" != "accepted" ]]; then
  fail "notarization was not accepted (status: ${STATUS:-unknown}). Check the log output above."
fi

printf '%s\n' '==> Notarization accepted. Stapling ticket...'

xcrun stapler staple "$DMG_PATH" || fail "stapler staple failed"

printf '%s\n' '==> Verifying Gatekeeper acceptance...'
spctl --assess --verbose --type install "$DMG_PATH" 2>&1 || fail "spctl assessment failed — Gatekeeper may reject this .dmg"

printf 'Notarized and stapled: %s\n' "$DMG_PATH"
printf '%s\n' 'Ready for distribution.'
