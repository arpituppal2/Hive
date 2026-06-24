#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Hive uses Swift Package Manager as the source of truth."
echo "Generate an Xcode workspace with one of:"
echo "  1. open Package.swift in Xcode 16+ (File > Open > Package.swift)"
echo "  2. xcodebuild -scheme HiveApp -destination 'platform=macOS' build"
echo ""
echo "Recommended schemes after opening in Xcode:"
echo "  - Hive macOS  -> HiveApp executable"
echo "  - Hive iPhone -> HiveMobileApp (iOS target when added)"
echo "  - Hive Watch  -> HiveWatchApp"
echo ""
echo "Run tests:"
echo "  swift test"
echo "  scripts/acceptance.sh"
