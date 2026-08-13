#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="$ROOT_DIR/scripts/verify-hive-entitlements.sh"
SOURCE="$ROOT_DIR/Sources/Hive/Hive.entitlements"

fail() {
  printf 'test-hive-entitlements: %s\n' "$1" >&2
  exit 1
}

[[ -x "$VALIDATOR" ]] || fail "validator must be executable: $VALIDATOR"
[[ -f "$SOURCE" ]] || fail "source policy is missing: $SOURCE"

fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/hive-entitlements.XXXXXX")"
cleanup() { rm -rf "$fixture_dir"; }
trap cleanup EXIT

"$VALIDATOR" "$SOURCE" >/dev/null

expect_rejected() {
  local fixture="$1"
  local label="$2"
  if "$VALIDATOR" "$fixture" >/dev/null 2>&1; then
    fail "$label fixture was accepted"
  fi
}

cp "$SOURCE" "$fixture_dir/missing.plist"
/usr/libexec/PlistBuddy -c 'Delete :com.apple.security.cs.allow-jit' "$fixture_dir/missing.plist" >/dev/null || \
  fail "could not create missing-key fixture"
expect_rejected "$fixture_dir/missing.plist" "missing-key"

cp "$SOURCE" "$fixture_dir/false.plist"
/usr/libexec/PlistBuddy -c 'Set :com.apple.security.cs.allow-jit false' "$fixture_dir/false.plist" >/dev/null || \
  fail "could not create false-value fixture"
expect_rejected "$fixture_dir/false.plist" "false-value"

cp "$SOURCE" "$fixture_dir/unexpected.plist"
/usr/libexec/PlistBuddy -c 'Add :com.apple.security.automation.apple-events bool true' "$fixture_dir/unexpected.plist" >/dev/null || \
  fail "could not create unexpected-key fixture"
expect_rejected "$fixture_dir/unexpected.plist" "unexpected-key"

printf 'Hive entitlement fixtures passed\n'
