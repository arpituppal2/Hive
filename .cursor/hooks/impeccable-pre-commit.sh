#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

npx impeccable detect . --json >/tmp/impeccable-detect.json
if [ -s /tmp/impeccable-detect.json ]; then
  cat /tmp/impeccable-detect.json
fi
