#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKER_IDENTIFIER="com.hive.browser.research-worker"
APP_PATH=""
WORKER_PATH=""
REQUIREMENT_PATH=""
TEAM_ID="${HIVE_WORKER_TEAM_ID:-${APPLE_TEAM_ID:-}}"
REQUIRE_STAPLED_TICKET=0

usage() {
  cat <<'USAGE'
Verify a signed Hive research worker before release packaging.

Usage:
  scripts/verify-research-worker.sh --app PATH [--team-id TEAM] [--require-stapled-ticket]
  scripts/verify-research-worker.sh --worker PATH --requirement PATH --team-id TEAM

Options:
  --app PATH                 Signed HiveChromium.app bundle. The worker and
                             requirement are located inside its Resources tree.
  --worker PATH              Explicit hive-fetch-worker path for CI fixtures.
  --requirement PATH         Explicit hive-worker-requirement.txt path.
  --team-id TEAM             Expected Developer ID Team ID. Defaults to
                             HIVE_WORKER_TEAM_ID, then APPLE_TEAM_ID.
  --require-stapled-ticket   Also require `xcrun stapler validate` on --app.
  -h, --help                Show this help.

This verifier never signs, notarizes, or modifies an artifact. It checks strict
code signatures, the helper identifier, the exact TeamIdentifier, the release
requirement shape, the SwiftPM resource-bundle layout, and (optionally) a
stapled notarization ticket. Notarization is not claimed without the explicit
stapler check.
USAGE
}

fail() {
  printf 'verify-research-worker: %s\n' "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      [[ $# -ge 2 ]] || { echo "--app requires a path" >&2; exit 2; }
      APP_PATH="$2"
      shift 2
      ;;
    --worker)
      [[ $# -ge 2 ]] || { echo "--worker requires a path" >&2; exit 2; }
      WORKER_PATH="$2"
      shift 2
      ;;
    --requirement)
      [[ $# -ge 2 ]] || { echo "--requirement requires a path" >&2; exit 2; }
      REQUIREMENT_PATH="$2"
      shift 2
      ;;
    --team-id)
      [[ $# -ge 2 ]] || { echo "--team-id requires a value" >&2; exit 2; }
      TEAM_ID="$2"
      shift 2
      ;;
    --require-stapled-ticket)
      REQUIRE_STAPLED_TICKET=1
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

command -v codesign >/dev/null 2>&1 || fail "codesign is required on macOS"
[[ -n "$TEAM_ID" ]] || fail "an expected Team ID is required; pass --team-id or set HIVE_WORKER_TEAM_ID/APPLE_TEAM_ID"
[[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || fail "Team ID must be the ten-character Apple identifier"
[[ "$TEAM_ID" != "0000000000" ]] || fail "the local-only dummy Team ID is not accepted by the release verifier"

if [[ -n "$APP_PATH" && -n "$WORKER_PATH" ]]; then
  fail "use --app or --worker, not both"
fi
if [[ -z "$APP_PATH" && -z "$WORKER_PATH" ]]; then
  fail "--app or --worker is required"
fi
if [[ "$REQUIRE_STAPLED_TICKET" -eq 1 && -z "$APP_PATH" ]]; then
  fail "--require-stapled-ticket requires --app"
fi

if [[ -n "$APP_PATH" ]]; then
  [[ -d "$APP_PATH" && "$APP_PATH" == *.app ]] || fail "--app must point to an existing .app bundle"
  APP_PATH="$(cd "$APP_PATH" && pwd)"
  [[ -d "$APP_PATH/Contents/Resources" ]] || fail "app has no Contents/Resources directory"

  worker_candidates=()
  while IFS= read -r -d '' candidate; do
    [[ -n "$candidate" ]] && worker_candidates[${#worker_candidates[@]}]="$candidate"
  done < <(find "$APP_PATH/Contents/Resources" -type f -path '*/ResearchWorker/hive-fetch-worker' -print0)
  [[ "${#worker_candidates[@]}" -eq 1 ]] || fail "expected exactly one ResearchWorker/hive-fetch-worker inside the app"
  WORKER_PATH="${worker_candidates[0]}"

  bundle_candidates=()
  while IFS= read -r -d '' candidate; do
    [[ -n "$candidate" ]] && bundle_candidates[${#bundle_candidates[@]}]="$candidate"
  done < <(find "$APP_PATH/Contents/Resources" -type d -name '*_HiveChromium.bundle' -path '*/Contents/Resources/*_HiveChromium.bundle' -print0)
  [[ "${#bundle_candidates[@]}" -eq 1 ]] || fail "expected exactly one HiveChromium SwiftPM resource bundle inside the app"
  RESOURCE_BUNDLE="${bundle_candidates[0]}"
  expected_prefix="$RESOURCE_BUNDLE/Contents/Resources/ResearchWorker/"
  [[ "$WORKER_PATH" == "$expected_prefix"* ]] || fail "worker is not inside the expected HiveChromium resource bundle"

  REQUIREMENT_PATH="$RESOURCE_BUNDLE/Contents/Resources/ResearchWorker/hive-worker-requirement.txt"
  codesign --verify --deep --strict --verbose=2 "$APP_PATH" >/dev/null 2>&1 || fail "app bundle strict code-signature verification failed"
  codesign --verify --strict --verbose=2 "$RESOURCE_BUNDLE" >/dev/null 2>&1 || fail "HiveChromium resource bundle signature verification failed"
else
  [[ -x "$WORKER_PATH" ]] || fail "worker is not executable: $WORKER_PATH"
  [[ -n "$REQUIREMENT_PATH" ]] || fail "--requirement is required with --worker"
fi

[[ -x "$WORKER_PATH" ]] || fail "worker is not executable: $WORKER_PATH"
[[ -f "$REQUIREMENT_PATH" ]] || fail "worker requirement file is missing"
case "$WORKER_PATH$REQUIREMENT_PATH" in
  *$'\\n'*|*$'\\r'*|*$'\\t'*) fail "worker and requirement paths contain unsupported control characters" ;;
esac

requirement_size="$(wc -c < "$REQUIREMENT_PATH" | tr -d '[:space:]')"
[[ "$requirement_size" =~ ^[0-9]+$ && "$requirement_size" -gt 0 && "$requirement_size" -le 4096 ]] || fail "worker requirement must be between 1 and 4096 bytes"

# Do not print the requirement: it is release configuration, not diagnostic output.
grep -Fq 'anchor apple generic' "$REQUIREMENT_PATH" || fail "requirement is missing the Developer ID anchor"
grep -Fq "identifier \"$WORKER_IDENTIFIER\"" "$REQUIREMENT_PATH" || fail "requirement does not name the Hive worker identifier"
grep -Fq "certificate leaf[subject.OU] = \"$TEAM_ID\"" "$REQUIREMENT_PATH" || fail "requirement does not pin the expected Team ID"

codesign --verify --strict --verbose=2 "$WORKER_PATH" >/dev/null 2>&1 || fail "worker strict code-signature verification failed"
# Evaluate the exact release requirement against the signed helper. This is
# stronger than comparing text fragments: Security.framework must accept the
# helper as satisfying the supplied requirement.
codesign -v -R="$REQUIREMENT_PATH" "$WORKER_PATH" >/dev/null 2>&1 || fail "worker does not satisfy the supplied release requirement"
metadata="$(codesign -dvvv "$WORKER_PATH" 2>&1)" || fail "could not inspect worker signature metadata"
team_identifier="$(printf '%s\n' "$metadata" | sed -n 's/^TeamIdentifier=//p' | head -1)"
[[ "$team_identifier" == "$TEAM_ID" ]] || fail "worker TeamIdentifier does not match the expected release Team ID"
worker_identifier="$(printf '%s\n' "$metadata" | sed -n 's/^Identifier=//p' | head -1)"
[[ "$worker_identifier" == "$WORKER_IDENTIFIER" ]] || fail "worker identifier does not match the Hive release contract"

designated_requirement="$(codesign -d -r- "$WORKER_PATH" 2>&1)" || fail "could not inspect worker designated requirement"
printf '%s\n' "$designated_requirement" | grep -Fq "$WORKER_IDENTIFIER" || fail "worker designated requirement does not name the Hive worker"
printf '%s\n' "$designated_requirement" | grep -Fq "$TEAM_ID" || fail "worker designated requirement does not contain the expected Team ID"

if [[ "$REQUIRE_STAPLED_TICKET" -eq 1 ]]; then
  command -v xcrun >/dev/null 2>&1 || fail "xcrun is required for stapled-ticket validation"
  xcrun stapler validate "$APP_PATH" >/dev/null 2>&1 || fail "app has no valid stapled notarization ticket"
fi

printf 'Verified Hive research worker: %s\n' "$WORKER_IDENTIFIER"
printf 'Verified Team ID: %s\n' "$TEAM_ID"
if [[ "$REQUIRE_STAPLED_TICKET" -eq 1 ]]; then
  printf '%s\n' 'Verified stapled notarization ticket: yes'
else
  printf '%s\n' 'Stapled notarization ticket: not checked (pass --require-stapled-ticket to require it)'
fi
