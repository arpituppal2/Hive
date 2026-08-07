#!/usr/bin/env bash
set -euo pipefail

ENTITLEMENTS_PATH="${1:-Sources/HiveChromium/HiveChromium.entitlements}"

fail() {
  printf 'verify-hivechromium-entitlements: %s\n' "$1" >&2
  exit 1
}

[[ "$(uname -s)" == "Darwin" ]] || fail "macOS is required"
[[ -f "$ENTITLEMENTS_PATH" ]] || fail "entitlements file is missing: $ENTITLEMENTS_PATH"
[[ -x /usr/libexec/PlistBuddy ]] || fail "PlistBuddy is required"
command -v plutil >/dev/null 2>&1 || fail "plutil is required"

plutil -lint "$ENTITLEMENTS_PATH" >/dev/null || fail "entitlements plist is invalid"

expected_keys=(
  "com.apple.security.cs.allow-jit"
  "com.apple.security.cs.allow-unsigned-executable-memory"
  "com.apple.security.cs.disable-library-validation"
)

read_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$ENTITLEMENTS_PATH" 2>/dev/null || return 1
}

for key in "${expected_keys[@]}"; do
  value="$(read_value "$key")" || fail "required entitlement is missing: $key"
  [[ "$value" == "true" ]] || fail "required entitlement must be true: $key (got $value)"
done

# PlistBuddy's top-level Print format is stable on macOS. Reject every
# top-level key outside the reviewed allowlist, including dangerous runtime,
# dyld, automation, sandbox, file, and network-server privileges.
while IFS= read -r line; do
  key="${line%% = *}"
  key="${key#${key%%[![:space:]]*}}"
  key="${key%${key##*[![:space:]]}}"
  [[ -n "$key" && "$key" != "Dict {" && "$key" != "}" ]] || continue
  allowed=0
  for expected in "${expected_keys[@]}"; do
    [[ "$key" == "$expected" ]] && allowed=1 && break
  done
  [[ "$allowed" -eq 1 ]] || fail "unexpected entitlement key: $key"
done < <(/usr/libexec/PlistBuddy -c 'Print :' "$ENTITLEMENTS_PATH" 2>/dev/null)

printf 'HiveChromium entitlements valid: %s\n' "$ENTITLEMENTS_PATH"
printf '%s\n' 'Reviewed allowlist: JIT, unsigned executable memory, CEF library validation'
