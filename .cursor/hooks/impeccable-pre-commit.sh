#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

npm run impeccable:detect >/tmp/impeccable-detect.json
if [ -s /tmp/impeccable-detect.json ]; then
  cat /tmp/impeccable-detect.json
fi
