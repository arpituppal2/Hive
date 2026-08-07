#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT_DIR/native/hive-fetch-boundary/Cargo.toml"
PROFILE="release"
RESOURCE_DIR="$ROOT_DIR/Sources/HiveChromium/Resources/ResearchWorker"
TARGET_DIR=""
ALLOW_ADHOC=0

usage() {
  cat <<'USAGE'
Build and stage Hive's Rust research worker.

Usage: scripts/build-research-worker.sh [options]

Options:
  --debug              Build the debug worker instead of release.
  --resource-dir DIR  Stage into DIR instead of HiveChromium Resources.
  --target-dir DIR    Use Cargo's target directory DIR.
  --allow-adhoc       Local development only; permits the all-zero dummy Team ID.
                       Never use this mode for a release artifact.
  -h, --help          Show this help.

The staged executable and requirement file are intentionally git-ignored.
Set HIVE_WORKER_REQUIREMENT to the exact macOS designated requirement for the
signed Hive helper and HIVE_WORKER_TEAM_ID (or APPLE_TEAM_ID) to the ten-character
Apple Team ID before staging. The release pipeline must sign the helper and
embed both files in the final app bundle before enabling production handoff.
The app rejects missing, malformed, or non-matching requirements.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)
      PROFILE="debug"
      shift
      ;;
    --resource-dir)
      [[ $# -ge 2 ]] || { echo "--resource-dir requires a path" >&2; exit 2; }
      RESOURCE_DIR="$2"
      shift 2
      ;;
    --target-dir)
      [[ $# -ge 2 ]] || { echo "--target-dir requires a path" >&2; exit 2; }
      TARGET_DIR="$2"
      shift 2
      ;;
    --allow-adhoc)
      ALLOW_ADHOC=1
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

TEAM_ID="${HIVE_WORKER_TEAM_ID:-${APPLE_TEAM_ID:-}}"
REQUIREMENT="${HIVE_WORKER_REQUIREMENT:-}"
if [[ -z "$REQUIREMENT" ]]; then
  echo "HIVE_WORKER_REQUIREMENT is required; refusing to stage an unauthenticated worker" >&2
  exit 2
fi
if [[ -z "$TEAM_ID" || ! "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "HIVE_WORKER_TEAM_ID or APPLE_TEAM_ID must be the ten-character Apple Team ID" >&2
  exit 2
fi
if [[ "$TEAM_ID" == "0000000000" && "$ALLOW_ADHOC" -ne 1 ]]; then
  echo "the all-zero Team ID is local-only; pass --allow-adhoc explicitly for development" >&2
  exit 2
fi
if [[ "$ALLOW_ADHOC" -eq 1 && "$TEAM_ID" != "0000000000" ]]; then
  echo "--allow-adhoc requires the all-zero local-only Team ID" >&2
  exit 2
fi
requirement_size="$(printf '%s' "$REQUIREMENT" | wc -c | tr -d '[:space:]')"
if [[ ! "$requirement_size" =~ ^[0-9]+$ || "$requirement_size" -eq 0 || "$requirement_size" -gt 4096 ]]; then
  echo "HIVE_WORKER_REQUIREMENT must be between 1 and 4096 bytes" >&2
  exit 2
fi
case "$REQUIREMENT" in
  *$'\\n'*|*$'\\r'*|*$'\\t'*)
    echo "HIVE_WORKER_REQUIREMENT contains an unsupported control character" >&2
    exit 2
    ;;
esac
printf '%s' "$REQUIREMENT" | grep -Fq 'anchor apple generic' || {
  echo "HIVE_WORKER_REQUIREMENT is missing the Developer ID anchor" >&2
  exit 2
}
printf '%s' "$REQUIREMENT" | grep -Fq "identifier \"com.hive.browser.research-worker\"" || {
  echo "HIVE_WORKER_REQUIREMENT does not name the Hive worker identifier" >&2
  exit 2
}
printf '%s' "$REQUIREMENT" | grep -Fq "certificate leaf[subject.OU] = \"$TEAM_ID\"" || {
  echo "HIVE_WORKER_REQUIREMENT does not pin the expected Team ID" >&2
  exit 2
}

CARGO_ARGS=(build --manifest-path "$MANIFEST" --bin hive-fetch-worker)
if [[ "$PROFILE" == "release" ]]; then
  CARGO_ARGS+=(--release)
fi
if [[ -n "$TARGET_DIR" ]]; then
  CARGO_ARGS+=(--target-dir "$TARGET_DIR")
fi

cargo "${CARGO_ARGS[@]}"

if [[ -n "$TARGET_DIR" ]]; then
  BUILT="$TARGET_DIR/$PROFILE/hive-fetch-worker"
else
  BUILT="$ROOT_DIR/native/hive-fetch-boundary/target/$PROFILE/hive-fetch-worker"
fi

[[ -x "$BUILT" ]] || {
  echo "cargo produced no executable worker at: $BUILT" >&2
  exit 1
}

mkdir -p "$RESOURCE_DIR"
REQUIREMENT_PATH="$RESOURCE_DIR/hive-worker-requirement.txt"
TEMP_REQUIREMENT_PATH="$(mktemp "${REQUIREMENT_PATH}.XXXXXX")"
cleanup() { rm -f "$TEMP_REQUIREMENT_PATH"; }
trap cleanup EXIT

cp "$BUILT" "$RESOURCE_DIR/hive-fetch-worker"
chmod 755 "$RESOURCE_DIR/hive-fetch-worker"

printf '%s\n' "$REQUIREMENT" > "$TEMP_REQUIREMENT_PATH"
chmod 644 "$TEMP_REQUIREMENT_PATH"
mv "$TEMP_REQUIREMENT_PATH" "$REQUIREMENT_PATH"

printf 'Staged %s\n' "$RESOURCE_DIR/hive-fetch-worker"
printf 'Staged %s\n' "$REQUIREMENT_PATH"
if [[ "$ALLOW_ADHOC" -eq 1 ]]; then
  printf '%s\n' 'Staged local ad-hoc helper; this artifact is not for distribution.'
else
  printf '%s\n' 'The helper remains unsigned until the app release pipeline signs it; the requirement file must match that signature before handoff is enabled.'
fi
