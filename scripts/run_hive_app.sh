#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: HiveApp can only be run on macOS." >&2
  exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
  echo "error: Xcode command line tools are not configured." >&2
  echo "Install Xcode, then run:" >&2
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi

XCODE_DEVELOPER_DIR="$(xcode-select -p)"
if [[ "$XCODE_DEVELOPER_DIR" == /Library/Developer/CommandLineTools* ]]; then
  echo "warning: xcode-select points at Command Line Tools, not full Xcode." >&2
  echo "Hive needs the Xcode toolchain. Run:" >&2
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  echo "Then retry this script." >&2
  exit 1
fi

echo "==> Using toolchain: $XCODE_DEVELOPER_DIR"
echo "==> Building and running HiveApp"
exec xcrun --sdk macosx swift run HiveApp "$@"
