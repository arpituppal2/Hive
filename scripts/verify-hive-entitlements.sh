#!/usr/bin/env bash
set -euo pipefail

ENTITLEMENTS_PATH="${1:-Sources/Hive/Hive.entitlements}"

fail() {
  printf 'verify-hive-entitlements: %s\n' "$1" >&2
  exit 1
}

[[ "$(uname -s)" == "Darwin" ]] || fail "macOS is required"
[[ -f "$ENTITLEMENTS_PATH" ]] || fail "entitlements file is missing: $ENTITLEMENTS_PATH"
[[ -x /usr/libexec/PlistBuddy ]] || fail "PlistBuddy is required"
command -v plutil >/dev/null 2>&1 || fail "plutil is required"

plutil -lint "$ENTITLEMENTS_PATH" >/dev/null || fail "entitlements plist is invalid"

required_keys=(
  "com.apple.security.cs.allow-jit"
  "com.apple.security.cs.allow-unsigned-executable-memory"
  "com.apple.security.cs.disable-library-validation"
)
optional_keys=(
  "com.apple.developer.icloud-container-identifiers"
  "com.apple.developer.icloud-services"
)

read_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$ENTITLEMENTS_PATH" 2>/dev/null || return 1
}

for key in "${required_keys[@]}"; do
  value="$(read_value "$key")" || fail "required entitlement is missing: $key"
  [[ "$value" == "true" ]] || fail "required entitlement must be true: $key (got $value)"
done

# CloudKit is optional. If present, require both pieces of the capability so
# a container identifier cannot be injected into a partially entitled bundle.
has_containers=0
has_services=0
if read_value "${optional_keys[0]}" >/dev/null; then has_containers=1; fi
if read_value "${optional_keys[1]}" >/dev/null; then has_services=1; fi
if [[ "$has_containers" -ne "$has_services" ]]; then
  fail "CloudKit entitlements must include both ${optional_keys[0]} and ${optional_keys[1]}"
fi
if [[ "$has_services" -eq 1 ]]; then
  services="$(/usr/libexec/PlistBuddy -c "Print :${optional_keys[1]}" "$ENTITLEMENTS_PATH" 2>/dev/null || true)"
  printf '%s\n' "$services" | grep -Eq '(^|[[:space:]])CloudKit([[:space:]]|$)' || \
    fail "CloudKit entitlements must include the CloudKit service"
fi

# PlistBuddy prints dictionary members with four spaces of indentation and
# nested array/dictionary members with deeper indentation. Inspect only the
# dictionary's direct members so array indexes cannot be mistaken for keys.
while IFS= read -r line; do
  [[ "$line" =~ ^[[:space:]]{4}[^[:space:]] ]] || continue
  key="${line%% = *}"
  key="${key#${key%%[![:space:]]*}}"
  key="${key%${key##*[![:space:]]}}"
  [[ -n "$key" && "$key" != "Dict {" && "$key" != "}" ]] || continue
  allowed=0
  for expected in "${required_keys[@]}" "${optional_keys[@]}"; do
    [[ "$key" == "$expected" ]] && allowed=1 && break
  done
  [[ "$allowed" -eq 1 ]] || fail "unexpected entitlement key: $key"
done < <(/usr/libexec/PlistBuddy -c 'Print :' "$ENTITLEMENTS_PATH" 2>/dev/null)

printf 'Hive entitlements valid: %s\n' "$ENTITLEMENTS_PATH"
printf '%s\n' 'Reviewed allowlist: CEF hardened runtime; optional iCloud container/services'
