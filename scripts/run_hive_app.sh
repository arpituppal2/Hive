#!/usr/bin/env bash
set -euo pipefail

find_xcode_developer_dirs() {
  local app
  while IFS= read -r app; do
    [[ -d "$app/Contents/Developer" ]] && printf '%s\n' "$app/Contents/Developer"
  done < <(
    mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" 2>/dev/null || true
    ls -1d /Applications/Xcode*.app 2>/dev/null || true
  )
}

pick_xcode_developer_dir() {
  if [[ -n "${DEVELOPER_DIR:-}" && -d "$DEVELOPER_DIR" ]]; then
    printf '%s\n' "$DEVELOPER_DIR"
    return 0
  fi

  local current
  if current="$(xcode-select -p 2>/dev/null)" && [[ "$current" != /Library/Developer/CommandLineTools* ]]; then
    printf '%s\n' "$current"
    return 0
  fi

  local candidate preferred
  for candidate in $(find_xcode_developer_dirs); do
    if [[ "$candidate" == *"Xcode-beta.app"* || "$candidate" == *"Xcode Beta.app"* ]]; then
      preferred="$candidate"
      break
    fi
    preferred="${preferred:-$candidate}"
  done

  [[ -n "$preferred" ]] && printf '%s\n' "$preferred"
}

print_xcode_select_help() {
  echo "Install or locate Xcode (release or beta), then run one of:" >&2
  local candidate
  while IFS= read -r candidate; do
    echo "  sudo xcode-select -s \"$candidate\"" >&2
  done < <(find_xcode_developer_dirs | sort -u)
  echo "Or set DEVELOPER_DIR for this shell only:" >&2
  echo "  export DEVELOPER_DIR=\"/Applications/Xcode-beta.app/Contents/Developer\"" >&2
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: HiveApp can only be run on macOS." >&2
  exit 1
fi

DEVELOPER_DIR="$(pick_xcode_developer_dir || true)"
if [[ -z "$DEVELOPER_DIR" ]]; then
  echo "error: No full Xcode developer directory found." >&2
  print_xcode_select_help
  exit 1
fi

if [[ "$(xcode-select -p 2>/dev/null || true)" == /Library/Developer/CommandLineTools* ]]; then
  echo "warning: xcode-select still points at Command Line Tools." >&2
  echo "Run:" >&2
  echo "  sudo xcode-select -s \"$DEVELOPER_DIR\"" >&2
  echo "Using DEVELOPER_DIR for this run: $DEVELOPER_DIR" >&2
fi

echo "==> Using toolchain: $DEVELOPER_DIR"
echo "==> Building and running HiveApp"
exec env DEVELOPER_DIR="$DEVELOPER_DIR" xcrun --sdk macosx swift run HiveApp "$@"
